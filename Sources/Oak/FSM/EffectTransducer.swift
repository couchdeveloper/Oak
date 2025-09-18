/// **EffectTransducer - Finite State Machine with Side Effects**
///
/// Extends pure state machines with controlled asynchronous side effects.
/// Maintains mathematical rigor while enabling real-world system integration.
///
/// EffectTransducers separate pure state logic from side effects, ensuring
/// deterministic behavior while enabling I/O, networking, timers, and other
/// async operations. Effects execute concurrently with state processing,
/// sending results back as events for continued state machine control.
///
/// ## Architecture Benefits
/// - **Pure State Logic**: State transitions remain deterministic and testable
/// - **Controlled Side Effects**: Async operations managed by transducer
///   lifecycle
/// - **Effect Cancellation**: Automatic cleanup when states become terminal
/// - **Event-Driven Results**: Effects send outcomes back as regular events
///
/// ## Effect Types
/// - **Action Effects**: Immediate, synchronous execution with state guarantees
/// - **Operation Effects**: Async Tasks with cancellation and error handling
///
/// ## Quick Example
/// ```swift
/// enum NetworkTransducer: EffectTransducer {
///     enum State { case idle, loading, loaded(Data), error(Error) }
///     enum Event { case load, dataReceived(Data), failed(Error) }
///
///     static func update(_ state: inout State, event: Event) -> Effect? {
///         switch (state, event) {
///         case (.idle, .load):
///             state = .loading
///             return networkEffect()
///         case (.loading, .dataReceived(let data)):
///             state = .loaded(data)
///             return nil
///         }
///     }
/// }
/// ```
///
/// > See `Oak Transducers.md` for effect patterns and architectural guidance.
public protocol EffectTransducer: BaseTransducer where Effect == Oak.Effect<Self> {
    
    /// The _Output_ of the FSM, which may include an optional
    /// effect and a value type, `Output`. Typically, for Effect-
    /// Transducers it is either `Effect?` or the tuple `(Effect?, Output)`.
    /// For non-effect transducers, it is simply `Output`.
    associatedtype TransducerOutput
    
    associatedtype Output = Void
    
    /// **Environment Type** - Dependency injection for effects.
    /// Provides context and services needed for side effect execution.
    associatedtype Env = Void

    /// **Pure State Transition with Effect Generation**
    ///
    /// The mathematical core enhanced with controlled side effect creation.
    /// Maintains deterministic state logic while enabling async operations.
    ///
    /// Returns effects for async work (networking, timers, I/O) while keeping
    /// state transitions pure and testable. Effects execute concurrently and
    /// send results back as events, maintaining the event-driven architecture.
    ///
    /// - Parameters:
    ///   - state: Current machine state (mutated for deterministic transitions)
    ///   - event: Triggering event from external sources or effect completions
    /// - Returns: `Effect?` (no output) or `(Effect?, Output)` (with output)
    ///
    /// ## Effect Integration Pattern
    /// ```swift
    /// static func update(_ state: inout State, event: Event) -> Effect? {
    ///     switch (state, event) {
    ///     case (.idle, .startLoad):
    ///         state = .loading
    ///         return networkEffect() // Async operation
    ///     case (.loading, .dataReceived(let data)):
    ///         state = .loaded(data)
    ///         return nil // Pure state transition
    ///     }
    /// }
    /// ```
    static func update(_ state: inout State, event: Event) -> TransducerOutput
}

/// Required for protocol conformance
extension EffectTransducer where TransducerOutput == (Effect?, Output) {
    
    @inline(__always)
    public static func compute(_ state: inout State, event: Event) -> (Effect?, Output) {
        update(&state, event: event)
    }

    @_disfavoredOverload
    @discardableResult
    public static func run(
        storage: some Storage<State>,
        proxy: Proxy = Proxy(),
        env: Env,
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
        try proxy.checkInUse()
        try Task.checkCancellation()
        let stream = proxy.stream
        let input = proxy.input
        let initialOutputValueOrNil = initialOutput(initialState: storage.value)
        if let initialOutputValue = initialOutputValueOrNil {
            try await output.send(initialOutputValue, isolated: systemActor)
        }
        try Task.checkCancellation()
        if storage.value.isTerminal {
            if let initialOutputValue = initialOutputValueOrNil {
                return initialOutputValue
            } else {
                throw TransducerError.noOutputProduced
            }
        }
        let context = Context(terminateProxy: { error in
            proxy.cancel(with: error)
        })
        var result: Output? = nil
        var events: [Event] = []
        events.reserveCapacity(4)
        do {
            loop: for try await event in stream {
                try Task.checkCancellation()
                var outputValue: Output?
                var nextEvent: Event? = event
                while let event = nextEvent {
                    let effect: Effect?
                    (effect, outputValue) = Self.compute(&storage.value, event: event)
                    try await output.send(outputValue!, isolated: systemActor)
                    
                    // Check if the state became terminal after processing this event
                    let isTerminated = storage.value.isTerminal
                    if isTerminated {
                        result = outputValue!
                        proxy.finish()
                        // Continue to execute the effect if present, but will break after
                    }
                    
                    if let effect {
                        let moreEvents = try await execute(
                            effect,
                            input: input,
                            env: env,
                            context: context
                        )
                        
                        // If state became terminal, don't process any returned events
                        if isTerminated {
                            break loop
                        }
                        
                        switch moreEvents.count {
                        case 0:
                            break
                        case 1:
                            nextEvent = moreEvents[0]
                            continue
                        default:
                            events.append(contentsOf: moreEvents)
                        }
                    } else if isTerminated {
                        // No effect to execute, break immediately
                        break loop
                    }
                    nextEvent = events.popLast()
                }
                try Task.checkCancellation()
                if storage.value.isTerminal {
                    result = outputValue!
                    proxy.finish()
                    break loop
                }
            }
            // Note:
            // There are four situations where the async loop will be exited:
            // 1. The transducer reaches a terminal state.
            // 2. The transducer has been forcibly terminated via the proxy.
            // 3. The current Task will be cancelled, which ends the iteration
            //    by returning `nil`.
            // 4. The transducer logic threw an error, in which case the
            //    async throwing stream throws an error.
        } catch TransducerError.cancelled {
            // We reach here, when the transducer has been forcibly terminated
            // via the proxy, i.e. by calling `proxy.cancel()`.
            // Eagerly cancel all tasks, if any:
            context.cancellAllTasks()
            throw TransducerError.cancelled
        } catch {
            // We reach here, when the transducer logic failed due to some
            // error, such as an operation failed, or sending an event failed
            // because the event buffer is full. We intercept here to just log
            // the error and then rethrow it:
            //
            // Caution: we do not reach here, when the current task has been
            // cancelled and has forcibly terminated the transducer.
            logger.info("Transducer '\(Self.self)' failed with error: \(error)")
            // Eagerly cancel all tasks, if any:
            context.cancellAllTasks()
            throw error
        }
        // The FSM reached terminal state, or the current task has been
        // cancelled. Iff there should be running effects, we eagerly cancel
        // them all:
        context.cancellAllTasks()

        // Iff the current task has been cancelled, we do still reach here. In
        // this case, the transducer may have been interupted being in a non-
        // terminal state and the event buffer may still containing unprocessed
        // events. We do explicitly throw a `CancellationError` to indicate
        // this fact:
        try Task.checkCancellation()

        #if DEBUG
        // Here, the event buffer may still have events in it, but the transducer
        // has finished processing. These events have been successfull enqueued,
        // and no error indicates this fact. In DEBUG we log these unprocessed
        // events, since it may indicate an error.
        var ignoreCount = 0
        for try await transducerEvent in proxy.stream {
            logger.info(
                "Transducer '\(Self.self)': ignoring event \(ignoreCount): \(String(describing: transducerEvent))"
            )
            ignoreCount += 1
        }
        #endif
        guard let result = result else {
            throw TransducerError.noOutputProduced
        }
        nonisolated(unsafe) let res = result
        return res
    }

    // /// Executes the Finite State Machine (FSM) with the given initial state.
    // ///
    // /// This overload of `run` is specialized for transducers where
    // /// `TransducerOutput == (Effect?, Output)`.
    // ///
    // /// The function `run(initialState:proxy:output:)` returns when the transducer
    // /// reaches a terminal state or when an error occurs.
    // ///
    // /// The proxy, or more specifically, the `Input` interface of the proxy, is used to
    // /// send events to the transducer. The output can be used to connect to other
    // /// components. This can also be another transducer. In this case, the output is
    // /// connected to the input interface of another transducer.
    // ///
    // /// - Parameter initialState: The initial state of the transducer.
    // /// - Parameter proxy: The transducer proxy that provides the input interface
    // ///   and an event buffer.
    // /// - Parameter env: The environment in which the transducer operates and which
    // /// provides the necessary context for executing effects.
    // /// - Parameter output: The subject to which the transducer's output will be
    // ///   sent.
    // /// - Parameter systemActor: The actor isolation context in which the transducer
    // ///   operates. This parameter allows the caller to specify the actor context
    // ///   for isolation, ensuring thread safety and correct actor execution semantics
    // ///   when running the transducer. The default value `#isolation` uses the
    // ///   current actor context.
    // ///
    // /// - Returns: The final output produced by the transducer when the state
    // ///   became terminal.
    // /// - Throws: An error if the transducer cannot execute its transition and
    // ///   output function as expected. For example, if the initial state is
    // ///   terminal, or if no output is produced, or when events could not be
    // ///   enqueued because of a full event buffer, or when the func `terminate()`
    // ///   is called on the proxy, or when the output value cannot be sent.
    // ///
    // /// > Note: State observation is not supported in this implementation of the
    // ///  run function.
    // ///
    // /// Specialization for transducers where `TransducerOutput == (Effect?, Output)`.
    // /// This overload is the public entry point for running a transducer with output emission.
    // /// - Note: The constraint `TransducerOutput == (Effect?, Output)` is required for this overload.
    // /// - See documentation above for details on this specialization.

    @_disfavoredOverload
    @discardableResult
    public static func run(
        initialState: State,
        proxy: Proxy = Proxy(),
        env: Env,
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
        try await Self.run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            env: env,
            output: output,
            systemActor: systemActor
        )
    }
    
    // /// Executes the Finate State Machine (FSM) with the given initial state.
    // ///
    // /// This overload of `run` is specialized for transducers where
    // /// `TransducerOutput == (Effect?, Output)`.
    // ///
    // /// The function `run(initialState:proxy:output:)` returns when the transducer
    // /// reaches a terminal state or when an error occurs.
    // ///
    // /// The proxy, or more specically, the `Input` interface of the proxy, is used to
    // /// send events to the transducer. The output can be used to connect to other
    // /// components. This can also be another transducer. In this case, the output is
    // /// connected to the input interface of another transducer.
    // ///
    // /// - Parameter initialState: The initial state of the transducer.
    // /// - Parameter proxy: The transducer proxy that provides the input interface
    // ///   and an event buffer.
    // /// - Parameter env: The environment in which the transducer operates and which
    // /// provides the necessary context for executing effects.
    // /// - Parameter systemActor: The actor isolation context in which the transducer
    // ///   operates. This parameter allows the caller to specify the actor context
    // ///   for isolation, ensuring thread safety and correct actor execution semantics
    // ///   when running the transducer. The default value `#isolation` uses the
    // ///   current actor context.
    // ///
    // /// - Throws: An error if the transducer cannot execute its transition and
    // ///   output function as expected. For example, if the initial state is
    // ///   terminal, or if no output is produced, or when events could not be
    // ///   equeued because of a full event buffer, or when the func `terminate()`
    // ///   is called on the proxy, or when the output value cannot be sent.
    // ///
    // /// > Note: State observation is not supported in this implementation of the
    // ///   run function.
    // ///
    // /// Specialization for transducers where `TransducerOutput == (Effect?, Output)`.
    // /// This overload is used when no output emission is required.
    // /// - Note: The constraint `TransducerOutput == (Effect?, Output)` is required for this overload.
    // /// - See documentation above for details on this specialization.
    // public static func run(
    //     initialState: State,
    //     proxy: Proxy,
    //     env: Env,
    //     systemActor: isolated any Actor = #isolation
    // ) async throws {
    //     _ = try await Self.run(
    //         storage: LocalStorage(value: initialState),
    //         proxy: proxy,
    //         env: env,
    //         output: NoCallback<Output>(),
    //         systemActor: systemActor
    //     )
    // }

}

/// Required for protocol conformance
extension EffectTransducer where TransducerOutput == Effect?, Output == Void {

    @inline(__always)
    public static func compute(_ state: inout State, event: Event) -> (Effect?, Output) {
        (update(&state, event: event), Void())
    }

    @_disfavoredOverload
    @discardableResult
    public static func run(
        storage: some Storage<State>,
        proxy: Proxy = Proxy(),
        env: Env,
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
        try Task.checkCancellation()
        try proxy.checkInUse()
        let stream = proxy.stream
        let input = proxy.input
        if storage.value.isTerminal {
            return
        }
        let context = Context(terminateProxy: { error in
            proxy.cancel(with: error)
        })
        var events: [Event] = []
        events.reserveCapacity(4)
        do {
            loop: for try await event in stream {
                try Task.checkCancellation()
                var nextEvent: Event? = event
                while let event = nextEvent {
                    let (effect, _) = Self.compute(&storage.value, event: event)
                    
                    // Check if the state became terminal after processing this event
                    let isTerminated = storage.value.isTerminal
                    if isTerminated {
                        proxy.finish()
                        // Continue to execute the effect if present, but will break after
                    }
                    
                    if let effect {
                        let moreEvents = try await execute(
                            effect,
                            input: input,
                            env: env,
                            context: context
                        )
                        
                        // If state became terminal, don't process any returned events
                        if isTerminated {
                            break loop
                        }
                        
                        switch moreEvents.count {
                        case 0:
                            break
                        case 1:
                            nextEvent = moreEvents[0]
                            continue
                        default:
                            events.append(contentsOf: moreEvents)
                        }
                    } else if isTerminated {
                        // No effect to execute, break immediately
                        break loop
                    }
                    nextEvent = events.popLast()
                }
                try Task.checkCancellation()
                if storage.value.isTerminal {
                    proxy.finish()
                    break loop
                }
            }
            // Note:
            // There are four situations where the async loop will be exited:
            // 1. The transducer reaches a terminal state.
            // 2. The transducer has been forcibly terminated via the proxy.
            // 3. The current Task will be cancelled, which ends the iteration
            //    by returning `nil`.
            // 4. The transducer logic threw an error, in which case the
            //    async throwing stream throws an error.
        } catch TransducerError.cancelled {
            // We reach here, when the transducer has been forcibly terminated
            // via the proxy, i.e. by calling `proxy.cancel()`.
            // Eagerly cancel all tasks, if any:
            context.cancellAllTasks()
            throw TransducerError.cancelled
        } catch {
            // We reach here, when the transducer logic failed due to some
            // error, such as an operation failed, or sending an event failed
            // because the event buffer is full. We intercept here to just log
            // the error and then rethrow it:
            //
            // Caution: we do not reach here, when the current task has been
            // cancelled and has forcibly terminated the transducer.
            logger.info("Transducer '\(Self.self)' failed with error: \(error)")
            // Eagerly cancel all tasks, if any:
            context.cancellAllTasks()
            throw error
        }
        // The FSM reached terminal state, or the current task has been
        // cancelled. Iff there should be running effects, we eagerly cancel
        // them all:
        context.cancellAllTasks()
        
        // Iff the current task has been cancelled, we do still reach here. In
        // this case, the transducer may have been interupted being in a non-
        // terminal state and the event buffer may still containing unprocessed
        // events. We do explicitly throw a `CancellationError` to indicate
        // this fact:
        try Task.checkCancellation()
        
#if DEBUG
        // Here, the event buffer may still have events in it, but the transducer
        // has finished processing. These events have been successfull enqueued,
        // and no error indicates this fact. In DEBUG we log these unprocessed
        // events, since it may indicate an error.
        var ignoreCount = 0
        for try await transducerEvent in proxy.stream {
            logger.info(
                "Transducer '\(Self.self)': ignoring event \(ignoreCount): \(String(describing: transducerEvent))"
            )
            ignoreCount += 1
        }
#endif
        return Void()
    }

    // /// Executes the Finite State Machine (FSM) with the given initial state.
    // ///
    // /// This overload of `run` is specialized for transducers where
    // /// `TransducerOutput == Effect?`.
    // ///
    // /// The function `run(initialState:proxy:output:)` returns when the transducer
    // /// reaches a terminal state or when an error occurs.
    // ///
    // /// The proxy, or more specifically, the `Input` interface of the proxy, is used to
    // /// send events to the transducer. The output can be used to connect to other
    // /// components. This can also be another transducer. In this case, the output is
    // /// connected to the input interface of another transducer.
    // ///
    // /// - Parameter initialState: The initial state of the transducer.
    // /// - Parameter proxy: The transducer proxy that provides the input interface
    // ///   and an event buffer.
    // /// - Parameter env: The environment in which the transducer operates and which
    // /// provides the necessary context for executing effects.
    // /// - Parameter systemActor: The actor isolation context in which the transducer
    // ///   operates. This parameter allows the caller to specify the actor context
    // ///   for isolation, ensuring thread safety and correct actor execution semantics
    // ///   when running the transducer. The default value `#isolation` uses the
    // ///   current actor context.
    // ///
    // /// - Throws: An error if the transducer cannot execute its transition and
    // ///   output function as expected. For example, if the initial state is
    // ///   terminal, or if no output is produced, or when events could not be
    // ///   enqueued because of a full event buffer, or when the func `terminate()`
    // ///   is called on the proxy, or when the output value cannot be sent.
    // ///
    // /// > Note: State observation is not supported in this implementation of the
    // ///  run function.

    @_disfavoredOverload
    @discardableResult
    public static func run(
        initialState: State,
        proxy: Proxy = Proxy(),
        env: Env,
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
        // Note: currently, this will call the overload which is NOT handling an output, in case Output == Void
        try await Self.run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            env: env,
            output: output,
            systemActor: systemActor
        )
    }
}

/// Convenience
extension EffectTransducer where TransducerOutput == Effect?, Output == Void {
    
    public static func run(
        storage: some Storage<State>,
        proxy: Proxy = Proxy(),
        env: Env,
        systemActor: isolated any Actor = #isolation
    ) async throws {
        try await Self.run(
            storage: storage,
            proxy: proxy,
            env: env,
            output: NoCallback<Void>(),
            systemActor: systemActor
        )
    }

    public static func run(
        initialState: State,
        proxy: Proxy = Proxy(),
        env: Env,
        systemActor: isolated any Actor = #isolation
    ) async throws {
        try await Self.run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            env: env,
            output: NoCallback<Void>(),
            systemActor: systemActor
        )
    }
}

extension EffectTransducer where TransducerOutput == (Effect?, Output) {
    
    @discardableResult
    public static func run(
        storage: some Storage<State>,
        proxy: Proxy = Proxy(),
        env: Env,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
        try await Self.run(
            storage: storage,
            proxy: proxy,
            env: env,
            output: NoCallback<Output>(),
            systemActor: systemActor
        )
    }

    
    @discardableResult
    public static func run(
        initialState: State,
        proxy: Proxy = Proxy(),
        env: Env,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
        try await Self.run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            env: env,
            output: NoCallback<Output>(),
            systemActor: systemActor
        )
    }
}


extension EffectTransducer {

    private static func execute(
        _ effect: consuming Effect,
        input: Input,
        env: Env,
        context: Context,
        isolated: isolated any Actor = #isolation
    ) async throws -> [Event] {
        try await effect.invoke(
            env: env,
            input: input,
            context: context,
            systemActor: isolated
        )
    }
}
