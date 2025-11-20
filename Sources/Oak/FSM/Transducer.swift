/// **Transducer - Pure Finite State Machine Protocol**
///
/// Defines deterministic event-driven state machines with mathematical rigor.
/// Eliminates edge cases through explicit (state, event) → outcome mappings.
///
/// Transducers embody finite state machine theory: every state/event combination
/// has a defined transition, making undefined behavior impossible. This mathematical
/// foundation transforms complex concurrent scenarios into predictable, testable logic.
///
/// ## Core Components
/// - **State**: Finite set of possible machine states with terminal detection
/// - **Event**: Input alphabet that drives state transitions
/// - **Output**: Optional values produced during transitions
/// - **update()**: Pure function encoding transition and output logic
///
/// ## Quick Example
/// ```swift
/// enum Counter: Transducer {
///     enum State { case idle(Int) }
///     enum Event { case increment, decrement }
///
///     static func update(_ state: inout State, event: Event) -> Int {
///         switch (state, event) {
///         case (.idle(let count), .increment):
///             state = .idle(count + 1)
///             return count + 1
///         case (.idle(let count), .decrement):
///             state = .idle(max(0, count - 1))
///             return max(0, count - 1)
///         }
///     }
/// }
/// ```
///
/// > See `Oak Transducers.md` for comprehensive guidance on state machine design,
/// > architectural patterns, and advanced usage scenarios.

public protocol Transducer: BaseTransducer where Effect == Never, Env == Void {

    associatedtype Event
    associatedtype State
    associatedtype Output = Void

    /// **Pure State Transition Function**
    ///
    /// The mathematical heart of the transducer. Maps (state, event) → (new_state, output)
    /// with complete determinism. Must handle ALL valid combinations explicitly.
    ///
    /// This function embodies finite state machine rigor: every reachable (state, event)
    /// pair must have a defined outcome. Missing cases indicate design gaps that could
    /// lead to runtime failures in traditional architectures.
    ///
    /// - Parameters:
    ///   - state: Current machine state (mutated in-place for efficiency)
    ///   - event: Triggering event from external sources or action effects
    /// - Returns: Output value sent to observers (Void if no output needed)
    ///
    /// ## Implementation Pattern
    /// ```swift
    /// static func update(_ state: inout State, event: Event) -> Output {
    ///     switch (state, event) {
    ///     case (.idle, .start): /* handle transition */
    ///     case (.processing, .complete): /* handle transition */
    ///     // Handle ALL reachable combinations - no defaults for expected cases
    ///     }
    /// }
    /// ```
    static func update(_ state: inout State, event: Event) -> Output
}

extension Transducer {

    @inline(__always)
    static func compute(_ state: inout State, event: Event) -> (Effect?, Output) {
        (.none, update(&state, event: event))
    }

    @discardableResult
    public static func run(
        storage: some Storage<State>,
        proxy: Proxy = Proxy(),
        env: Env = (),
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
        try proxy.checkInUse()
        try Task.checkCancellation()
        let stream = proxy.stream
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
        var result: Output? = nil
        do {
            loop: for try await event in stream {
                try Task.checkCancellation()
                let (_, outputValue) = Self.compute(&storage.value, event: event)
                try await output.send(outputValue, isolated: systemActor)
                try Task.checkCancellation()
                if storage.value.isTerminal {
                    result = outputValue
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
            logger.info("Transducer '\(Self.self)' cancelled")
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
            throw error
        }
        // If the current task has been cancelled, we do still reach here. In
        // this case, the transducer may have been interupted being in a non-
        // terminal state and the event buffer may still contain unprocessed
        // events. We do explicitly throw a `CancellationError` to indicate
        // this fact:
        try Task.checkCancellation()

        // If we reach here, the transducer should be terminated normally, i.e.
        // the state is terminal.
        #if DEBUG
        // Here, the event buffer may still have events in it, but the transducer
        // has finished processing. These events have been successfull enqueued,
        // and no error indicates this fact. In DEBUG we log these unprocessed
        // events, since it may indicate an error.
        var ignoreCount = 0
        for try await transducerEvent in proxy.stream {
            logger.warning(
                """
                Transducer '\(Self.self)': ignoring event \(ignoreCount): \
                \(String(describing: transducerEvent))
                """
            )
            ignoreCount += 1
        }
        #endif
        guard let result = result else {
            throw TransducerError.noOutputProduced
        }
        return result
    }

    @discardableResult
    public static func run(
        initialState: State,
        proxy: Proxy = Proxy(),
        env: Env = (),
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
        return try await Self.run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            env: env,
            output: output,
            systemActor: systemActor
        )
    }

}

extension Transducer {

    /// Executes the Finite State Machine (FSM) with the given observable state.
    ///
    /// The function `run(initialState:proxy:)` returns when the transducer
    /// reaches a terminal state or when an error occurs.
    ///
    /// The proxy, or more specifically, the `Input` interface of the proxy, is used to
    /// send events to the transducer. The output can be used to connect to other
    /// components. This can also be another transducer. In this case, the output is
    /// connected to the input interface of another transducer.
    ///
    /// - Parameter state: A reference-writeable key path to the state.
    /// - Parameter host: The host providing the backing store for the state.
    /// - Parameter proxy: The transducer proxy that provides the input interface
    ///   and an event buffer.
    ///   with `EffectTransducer` and to support composition patterns.
    /// - Parameter output: The subject to which the transducer's output will be
    ///   sent.
    /// - Parameter systemActor: The isolation of the caller.
    ///
    /// - Throws: An error if the transducer cannot execute its transition and
    ///   output function as expected. For example, if the initial state is
    ///   terminal, or if no output is produced, or when events could not be
    ///   enqueued because of a full event buffer, or when the func `terminate()`
    ///   is called on the proxy, or when the output value cannot be sent.
    ///
    @discardableResult
    public static func run<Host>(
        state: ReferenceWritableKeyPath<Host, State>,
        host: Host,
        proxy: Proxy = Proxy(),
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
        try await run(
            storage: ReferenceKeyPathStorage(host: host, keyPath: state),
            proxy: proxy,
            env: Void(),
            output: output,
            systemActor: systemActor
        )
    }

    /// Creates a transducer with an observable state whose update function has the
    /// signature `(inout State, Event) -> Output`.
    ///
    /// The update function is isolated by the given Actor, that can be explicitly
    /// specified, or it will be inferred from the caller. If it's not specified,
    /// and the caller is not isolated, the compilation will fail.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - state: A reference-writeable key path to the state.
    ///   - host: The host providing the backing store for the state.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   transducers, its type is always `Void`. This parameter exists for consistency
    ///   with `EffectTransducer` and to support composition patterns.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by
    ///   the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the
    ///   Swift Task, where the transducer is running on, has been cancelled, or
    ///   when it has been forcibly terminated, and thus could not reach a
    ///   terminal state.
    @discardableResult
    public static func run<Host>(
        state: ReferenceWritableKeyPath<Host, State>,
        host: Host,
        proxy: Proxy = Proxy(),
        isolated: isolated any Actor = #isolation
    ) async throws -> Output {
        try await run(
            storage: ReferenceKeyPathStorage(host: host, keyPath: state),
            proxy: proxy,
            env: Void(),
            output: NoCallback<Output>()
        )
    }

}

// MARK: Convenient Function when no output parameter is given

extension Transducer {

    /// Executes the Finite State Machine (FSM) by using the given storage as
    /// as a reference to its state. The current value of the state is the
    /// initial state of the FSM.
    ///
    /// The function `run(storage:proxy:env:output:systemActor:)` returns
    /// when the transducer reaches a terminal state or when an error occurs.
    ///
    /// The proxy, or more specifically, the `Input` interface of the proxy, is used to
    /// send events to the transducer. The output can be used to connect to other
    /// components. This can also be another transducer. In this case, the output is
    /// connected to the input interface of another transducer.
    ///
    /// - Parameter storage: A reference to a storage which is used by the transducer
    ///   to store its state. The storage must conform to the `Storage` protocol.
    ///   The storage is used to read and write the state of the transducer.
    /// - Parameter proxy: The transducer proxy that provides the input interface
    ///   and an event buffer.
    /// - Parameter systemActor: The isolation of the caller.
    ///
    /// > Note: State observation is not supported in this implementation of the
    ///   run function.
    ///
    /// - Throws:
    ///   - `TransducerError.noOutputProduced`: If no output is produced before
    ///     reaching the terminal state.
    ///   - Other errors: If the transducer cannot execute its transition and
    ///     output function as expected, for example, when events could not be
    ///     enqueued because of a full event buffer, when the func `terminate()`
    ///     is called on the proxy, or when the output value cannot be sent.
    ///
    public static func run(
        storage: some Storage<State>,
        proxy: Proxy = Proxy(),
        systemActor: isolated any Actor = #isolation
    ) async throws {
        try await run(
            storage: storage,
            proxy: proxy,
            env: Void(),
            output: NoCallback<Output>(),
            systemActor: systemActor
        )
    }
}

extension Transducer {

    /// Executes the Finite State Machine (FSM) with the given initial state.
    ///
    /// The function `run(initialState:proxy:)` returns when the transducer
    /// reaches a terminal state or when an error occurs.
    ///
    /// The proxy, or more specifically, the `Input` interface of the proxy, is used to
    /// send events to the transducer. The output can be used to connect to other
    /// components. This can also be another transducer. In this case, the output is
    /// connected to the input interface of another transducer.
    ///
    /// - Parameter initialState: The initial state of the transducer.
    /// - Parameter proxy: The transducer proxy that provides the input interface
    ///   and an event buffer.
    ///   with `EffectTransducer` and to support composition patterns.
    /// - Parameter systemActor: The isolation of the caller.
    ///
    /// > Note: State observation is not supported in this implementation of the
    ///   run function.
    ///
    /// - Throws: An error if the transducer cannot execute its transition and
    ///   output function as expected. For example, if the initial state is
    ///   terminal, or if no output is produced, or when events could not be
    ///   enqueued because of a full event buffer, or when the func `terminate()`
    ///   is called on the proxy, or when the output value cannot be sent.
    ///
    public static func run(
        initialState: State,
        proxy: Proxy = Proxy(),
        systemActor: isolated any Actor = #isolation
    ) async throws {
        try await run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            env: Void(),
            output: NoCallback<Output>(),
            systemActor: systemActor
        )
    }

}
