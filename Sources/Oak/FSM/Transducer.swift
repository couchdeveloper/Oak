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
/// The protocol `Transducer` defines the interface for a finite state machine (FSM) 
/// that can process events and produce output based on its current state and the 
/// input events it receives. 
/// 
/// The terminology of the protocol `Transducer` uses the name `Event` instead of 
/// "Input" to better reflect the nature of the input of the FSM in a software 
/// implementation, which are in fact _events_ that happen in the system and that 
/// the FSM can process.
/// 
/// In addition to this, the protocol `Transducer` does not require a separate 
/// transition and output function, but instead combines these two functions into a
/// single function called `update`. This function takes the current state and an
/// input event and returns the output value produced by the FSM. The state is
/// updated in place.
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
///
/// ## Usage Examples
///
/// ### Defining a Transducer
///
/// Below is a very basic FSM (`T1`) showing how to define State, Event
/// and the update function. The FSM is not producing an output.
///
///```swift
///enum T1: Transducer {
///    enum State: Terminable {
///        case start
///        case terminated
///        var isTerminal: Bool {
///            if case .terminated = self { true } else { false }
///        }
///    }
///
///    enum Event { case start }
///
///    static func update(
///        _ state: inout State,
///        event: Event
///    ) -> Void {
///        switch (event, state) {
///        case (.start, .start):
///            state = .terminated
///        case (_, .terminated):
///            return
///        }
///    }
///}
///```
/// ### Executing a FSM
///
/// A finite state machine will be finally created and put into the initial state
/// with the protocol extension function `run()`. The function is async and
/// throwing. The function returns when the transducer's state transitioned to
/// a terminal state.
///
/// The `run()` function has a couple of overloads. The exact overload
/// to use depends an how the FSM has been defined.
///
/// For example, the transducer `T1` in the given example above, can be
/// executed as shown below:
///
///```swift
///let proxy = T1.Proxy()
///try await T1.run(
///    initialState: .start,
///    proxy: proxy,
///)
///```
/// Elsewhere, the `proxy` will be used to send events into the FSM:
///```swift
///proxy.send(.start)
///```
/// In the example above, once the FSM receives an event `start` it also
/// will terminate and the asynchronous `run()` will return.


public protocol Transducer: BaseTransducer {
    
    associatedtype Event
    associatedtype State
    associatedtype Output
    
    /// A pure function that combines the _transition_ and the _output_ function
    /// of the finite state machine (FSM) into a single function.
    ///
    /// - Parameters:
    ///   - state: The current state of the FSM, which may be mutated to reflect the transition.
    ///   - event: The event to process.
    /// - Returns: A value of type `Output`
    ///
    /// > Note: The output value will be sent to the output subject which is given as a
    /// parameter in the `run` function.
    static func update(_ state: inout State, event: Event) -> Output
}

extension Transducer {
    
    package static func run(
        storage: some Storage<State>,
        proxy: Proxy,
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output where Proxy.Event == Event {
        try proxy.checkInUse()
        let stream = proxy.stream
        let initialOutputValueOrNil = initialOutput(initialState: storage.value) 
        if let initialOutputValue = initialOutputValueOrNil {
            try await output.send(initialOutputValue, isolated: systemActor)
        }
        if storage.value.isTerminal {
            if let initialOutputValue = initialOutputValueOrNil {
                return initialOutputValue
            } else {
                throw TransducerError.noOutputProduced
            }
        }
        var result: Output? = nil
        do  {
            loop: for try await event in stream {
                let outputValue = Self.update(&storage.value, event: event)
                try await output.send(outputValue, isolated: systemActor)
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
            logger.warning("Transducer '\(Self.self)': ignoring event \(ignoreCount): \(String(describing: transducerEvent))")
            ignoreCount += 1
        }
#endif
        guard let result = result else {
            throw TransducerError.noOutputProduced
        }
        return result
    }
}

extension Transducer {
    
    /// Executes the Finite State Machine (FSM) with the given initial state.
    /// 
    /// The function `run(initialState:proxy:output:)` returns when the transducer
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
    /// - Parameter output: The subject to which the transducer's output will be
    ///   sent.
    /// - Parameter systemActor: The isolation of the caller.
    ///
    /// > Note: State observation is not supported in this implementation of the
    ///   run function.
    /// 
    /// - Returns: The final output produced by the transducer when the state
    ///   becomes terminal.
    /// 
    /// - Throws: 
    ///   - `TransducerError.noOutputProduced`: If no output is produced before reaching the terminal state.
    ///   - Other errors: If the transducer cannot execute its transition and output function as expected, 
    ///     for example, when events could not be enqueued because of a full event buffer, 
    ///     when the func `terminate()` is called on the proxy, or when the output value cannot be sent.
    /// 
    @discardableResult
    public static func run(
        initialState: State,
        proxy: Proxy,
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
       return try await Self.run(
            storage: LocalStorage(value: initialState), 
            proxy: proxy, 
            output: output,
            systemActor: systemActor
        )
    }
    
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
        proxy: Proxy,
        systemActor: isolated any Actor = #isolation
    ) async throws where Output == Void {
       try await Self.run(
            storage: LocalStorage(value: initialState), 
            proxy: proxy, 
            output: NoCallback<Void>(),
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
        proxy: Proxy,
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
        try await run(
            storage: ReferenceKeyPathStorage(host: host, keyPath: state),
            proxy: proxy,
            output: output,
            systemActor: systemActor
        )   
    }
    
    /// Creates a transducer with an observable state whose update function has the signature
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function is isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - state: A reference-writeable key path to the state.
    ///   - host: The host providing the backing store for the state.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run<Host>(
        state: ReferenceWritableKeyPath<Host, State>,
        host: Host,
        proxy: Proxy,
        isolated: isolated any Actor = #isolation,
    ) async throws -> Output {
        try await run(
            storage: ReferenceKeyPathStorage(host: host, keyPath: state),
            proxy: proxy,
            output: NoCallback<Output>()
        )
    }

}
