/// **BaseTransducer - Type Composition Foundation**
///
/// Defines transducer type contracts without implementation requirements.
/// Enables architectural flexibility through composition and delegation patterns.
///
/// BaseTransducer serves as a type container for building sophisticated state machine 
/// hierarchies. Unlike concrete transducers, it focuses on type composition rather
/// than state mutation, making it ideal for coordinator and composite patterns.
///
/// ## Key Design Benefits
/// - **Compositional Architecture**: Build complex systems from simpler parts
/// - **Hierarchical State Machines**: Parent coordinators with leaf state machines  
/// - **Type Safety**: Enforce contracts without forcing implementation details
/// - **Delegation Patterns**: Route behavior to appropriate concrete transducers
///
/// ## Architecture Patterns
/// ```swift
/// // Coordinator that delegates to concrete transducers
/// enum AppCoordinator: BaseTransducer {
///     typealias State = AppState
///     typealias Event = AppEvent
///     // Delegates to LoginTransducer, DashboardTransducer, etc.
/// }
/// ```
///
/// > See `Oak Transducers.md` for composition patterns and architectural guidance.
public protocol BaseTransducer<Event> {
    
    /// **State Type** - Machine state space with terminal detection.
    /// Must conform to `Terminable` for proper lifecycle management.
    associatedtype State: Terminable
    
    /// **Event Type** - Input alphabet that drives state transitions.
    /// Represents all possible triggers the transducer can process.
    associatedtype Event
    
    // associatedtype TransducerOutput
    
    /// The type of the input interface of the transducer proxy.
    ///
    /// This is used to send events to the transducer.
    typealias Input = Proxy.Input
    
    /// Part of the _Output_ of the FSM, which includes all non-effects.
    ///
    /// An output value will be produced by the transducer in every computation
    /// cycle. The transducer can optionally define a `Subject`, which is a
    /// means to let other components observe the output.
    ///
    /// `Output` may be `Void`, which means that the FSM does not
    /// produce an output.
    ///
    /// > Note: An _EffectTransducer_ always has an `Effect` type as part of its
    ///   `TransducerOutput`. This is a tuple of the form `(Effect?, Output)`
    ///   in cases where `Output`` is not `Void`. Otherwise, the `TransducerOutput`
    ///   is simply `Effect?`.
    ///
    associatedtype Output

    /// The type of the effect a transducer may return in its update function.
    /// This is `Never` for non-effect transducers.
    associatedtype Effect
    
    /// The type of the environment in which the transducer operates.
    ///
    /// The environment provides the necessary context for executing the transducer.
    /// This allows the transducer to interact with the outside world in a controlled way.
    ///
    /// > Note:  For non-effect transducers, its type is always `Void`.
    associatedtype Env
        
    /// The type of the transducer proxy.
    ///
    /// A proxy is required to execute a transducer to provide the input
    /// interface and to provide an event buffer. It also provides the
    /// ability to terminate the transducer and cases where this should
    /// be necessary.
    ///
    /// The default type for the Proxy is `Proxy<Event>`, which provides
    /// a "fire & forget" style of event sending and also requires an internal
    /// event buffer. Sending may fail if the buffer is full.
    ///
    /// The other built-in proxy is `SyncSuspendingProxy<Event>`, which provides
    /// an async interface for sending events. This interface suspends until
    /// the event has been processed. It does not require an internal event
    /// buffer and sending also cannot fail. This effectively implements
    /// a backpressure mechanism, which prevent a producer to overwhelm the
    /// transducer. The internal processing of the event is usually
    /// extremely fast, but if a transducer sends output to the subject,
    /// subscribers may block the processing of the event.
    associatedtype Proxy: TransducerProxy<Event> & TransducerProxyInternal = Oak.Proxy<Event>
    
    /// This function needs to be defined and return a non-nil Output value
    /// to ensure correct behaviour of Moore type transducers.
    ///
    /// This function is used to provide an initial output value when the
    /// transducer is initialized with an initial state. For Moore type
    /// transducers, this is necessary to ensure that the transducer can
    /// produce an output value immediately after initialization.
    ///
    /// The default implementation returns `nil`.
    static func initialOutput(initialState: State) -> Output?
        
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
    /// - Parameter env: The environment used for the transducer.
    ///    > Note: For non-effect transducers, its type is always `Void`.
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
    static func run(
        storage: some Storage<State>,
        proxy: Proxy,
        env: Env,
        output: some Subject<Output>,
        systemActor: isolated any Actor
    ) async throws -> Output
    
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
    /// - Parameter env: The environment used for the transducer. For non-effect
    ///   transducers, its type is always `Void`. This parameter exists for consistency
    ///   with `EffectTransducer` and to support composition patterns.
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
    static func run(
        initialState: State,
        proxy: Proxy,
        env: Env,
        output: some Subject<Output>,
        systemActor: isolated any Actor
    ) async throws -> Output
}

extension BaseTransducer {
    public static func initialOutput(initialState: State) -> Output? {
        return nil
    }
}
