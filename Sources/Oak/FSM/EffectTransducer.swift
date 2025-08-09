/// A type that describes the behavior and its constituting parts of a
/// Finite State Machine (FSM).
///
/// A Finite State Machine (FSM) is a computational model that can be in one
/// of a finite number of states at any given time. It can transition between
/// these states based on input events, and it can produce output based on
/// its current state and the input events it receives.
///
/// A FSM is also called a finite state transducer (FST) or simply a transducer,
/// when it produces output based on the input events and its current state.
///
/// A FSM is a tuple of the form:
/// $(States, Inputs, Initial State, Transition Function, Output Function)$
/// - `States`: A finite set of states that the FSM can be in.
/// - `Inputs`: A finite set of input events that the FSM can receive.
/// - `Initial State`: The state in which the FSM starts.
/// - `Transition Function`: A function that takes the current state and an input
///   event and returns the next state.
/// - `Output Function`: A function that takes the current state and an input event
///   and returns an output value.
///
/// The protocol `EffectTransducer` defines the interface for a finite state
/// machine (FSM) that can process events and produce output based on its current
/// state and the input events it receives.
///
/// In addition to the FSM's behavior, the protocol also allows for the definition
/// of side effects that can occur during the processing of events. A side effect
/// is an operation that has an observable interaction with the outside world.
/// Effects are created within the FSM's update function and returned as part of
/// the transducer's output.
///
/// Effects are a powerful way to call asynchronous operations, such as network
/// requests or database updates. The effects can send events back into the transducer
/// using the provided `Input` interface of the transducer proxy. This allows for
/// a seamless integration of asynchronous operations into the FSM's processing
/// logic, enabling the FSM to react to the results of these operations.
///
/// The transducer manages these effects by providing a way to define and handle
/// them within the FSM's processing logic. This also includes the ability to
/// cancel the effects by referencing the effect with a unique ID and sending a
/// cancellation event from within the update function. Effects can also spawn new
/// transducers expanding the FSM's capabilities. The life-cycle of effects is
/// managed by the transducer itself, which keeps track of all active effects.
/// When a transducer reaches a terminal state, it will automatically cancel all
/// active effects, ensuring that no further operations are performed.
///
/// The terminology of the protocol `Transducer` uses the name `Event` instead of
/// "Input" to better reflect the nature of the input of the FSM in a software
/// implementation, which are in fact _events_ that happen in the system and that
/// the FSM can process.
///
/// The protocol `Transducer` does not require a separate transition and output
/// function, but instead combines these two functions into a single function
/// called `update`. This function takes the current state and an input event
/// and returns the output value produced by the FSM. The state is updated in
/// place.
///
/// Due to this design, the specific implementation of a FSM allows for socalled
/// Moore or Mealy machines, where the output can be produced based on the current
/// state (Moore) or the current state and the input event (Mealy), respectively.
///
/// Note that a conforming type describes the behavior of a transducer, but does not
/// implement the state machine itself. The actual state machine is created by
/// executing the `run` function, which takes an initial state and a transducer proxy.
///
/// The asynchronous throwing `run` function also represents the life-cycle of the
/// transducer. It returns when the transducer reaches a terminal state or when an
/// error occurs.
///
/// Note also, that this design requires no objects or classes to be created
/// to represent the transducer. The transducer is a pure function that can be
/// executed in an asynchronous context, and it can be used to process events and
/// produce output.
public protocol EffectTransducer: BaseTransducer where Effect == Oak.Effect<Self> {
    
    /// The _Output_ of the FSM, which may include an optional
    /// effect and a value type, `Output`. Typically, for Effect-
    /// Transducers it is either `Effect?` or the tuple `(Effect?, Output)`.
    /// For non-effect transducers, it is simply `Output`.
    associatedtype TransducerOutput
    
    associatedtype Output = Void
    
    /// The type of the environment in which the transducer operates and which
    /// provides the necessary context for executing effects.
    associatedtype Env = Void

    /// A pure function that combines the _transition_ and the _output_ function
    /// of the finite state machine (FSM) into a single function.
    ///
    /// - Parameters:
    ///   - state: The current state of the FSM, which may be mutated to reflect the transition.
    ///   - event: The event to process.
    /// - Returns: A value of type `Output`
    ///
    /// > Note: The return type`TransducerOutput` can be either a `Effect?` or a
    /// tuple `(Effect?, Output)`. The output value will be sent to the output subject
    /// which is given as a parameter in the `run` function.
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
                    if let effect {
                        let moreEvents = try await execute(
                            effect,
                            input: input,
                            env: env,
                            context: context
                        )
                        switch moreEvents.count {
                        case 0:
                            break
                        case 1:
                            nextEvent = moreEvents[0]
                            continue
                        default:
                            events.append(contentsOf: moreEvents)
                        }
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
        try proxy.checkInUse()
        try Task.checkCancellation()
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
                    if let effect {
                        let moreEvents = try await execute(
                            effect,
                            input: input,
                            env: env,
                            context: context
                        )
                        switch moreEvents.count {
                        case 0:
                            break
                        case 1:
                            nextEvent = moreEvents[0]
                            continue
                        default:
                            events.append(contentsOf: moreEvents)
                        }
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
