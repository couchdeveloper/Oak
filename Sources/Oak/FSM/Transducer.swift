
/// A conforming type defines a concrete _model of computation_
/// or _abstract machine_ for an _extended_ Finite State Machine (FSM).
///
/// When a FSM produces an output, which is optional for an FSM, the FSM
/// is said to be a _Finite State Transducer_ (FST). Oak frequently uses the
/// term FST even though it might be an FSM not producing an output.
///
/// A conforming type defines `State`, `Event`, `TransducerOutput`
/// and the update function `update(_:event:) -> TransducerOuptut`
/// for the FSM. The update function combines the _transition_ and _output_
/// function.
///
/// ## Defining the FSM
///
/// Below is a very basic FSM (`T1`) which is not producing an output:
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
///    enum Event { case start }
///    static func update(
///        _ state: inout State,
///        event: Event
///    ) -> Void {
///        switch (event, state) {
///        case (.start, .start):
///            return .terminated
///        case (_, .terminated):
///            return state
///        }
///    }
///}
///```
///
/// The next example (`T2`) uses a more advanced FST which produces an
/// output on every transition with is a tuple of an _effect_ and a value (here
/// a tuple). The effect in this example is a very basic one, which simply sends
/// an event `ping` after a specified duration to the FST when it gets executed.
/// When the FST receives an event `ping` it will send another effect which
/// will send the event `ping` to the transducer after the duration. The FST
/// can be terminated by sending it the `cancel` event.
///
/// Note that the FST will handle the effect execution already, and there's
/// nothing more one needs to do.
///```swift
/// enum T1: Transducer {
///     enum State: Terminable {
///         case start, running, finished
///         var isTerminal: Bool {
///             if case .finished = self { true } else { false }
///         }
///     }
///     enum Event {
///         case start, cancel, ping
///     }
///
///     struct Env {}
///
///     typealias Effect = Oak.Effect<Self>
///
///     static func update(_ state: inout State, event: sending Event) -> (Effect?, (Int, String)) {
///         switch (event, state) {
///         case (.start, .start):
///             state = .running
///             return (.event(.ping, id: "ping", after: .milliseconds(100)), (0, "running"))
///         case (.start, .running):
///             return (.none, (1, "running"))
///         case (.cancel, .running):
///             state = .finished
///             return (.none, (2, "finished"))
///         case (.ping, .running):
///             return (.event(.ping, id: "ping", after: .milliseconds(100)), (3, "ping"))
///
///         case (_, .finished):
///             return (.none, (-1, "??"))
///         case (.ping, .start):
///             return (.none, (-1, "??"))
///         case (.cancel, .start):
///             return (.none, (-1, "??"))
///         }
///     }
/// }
///```
///
/// ## Executing a FSM
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
/// exeuted as shown below:
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
/// In the example above, once the FSM receices an event `start` it also
/// will terminate and the asynchronous `run()` will return.
///
/// The transducer `T2` in the given example executes an effect. Due
/// to this, it requires an additional parameter which is the
/// "environment" for the side effect which will be executed by the FSM.
///
/// To exetute the FSM we need to provide the environment as shown
/// below:
///
///```swift
/// let proxy = T2.Proxy()
/// let env = T2.Env()
///
/// let result = try await T2.run(
///     initialState: .start,
///     proxy: proxy,
///     env: env
/// )
///```
/// Elsewhere we can use the proxy to send events into the FSM `T2`:
///```swift
///try proxy.send(.start)
///```
/// In the example `T2` above this will cause the FSM to transition to
/// the `running` state.
///
/// In order to put the FSM `T2` into the terminal state (i.e. it will finish) we
/// can send the `cancel` event:
///```swift
///try proxy.send(.cancel)
///```
/// This will eventually cause the FSM's `run` function to return and yield
/// the final result - which is the last output value generated by the FSM
/// during its last transition into the terminal state.
///
/// Note that all events are specific to the use case `T2`.
///
///
/// ## Thread-safety
///
/// A FSM needs to run in an _isolated domain_, that needs to be provided
/// by the call-site. Isolation basically means, that the _state_ is _isolated_
/// and mutation of the state respects thread-safety. While this is an implementation
/// detail of an abstract machine, it is crucial for a correct implementation in
/// software within a concurrent environment. In Oak, the isolation will be
/// realised with an `Swift.Actor`.
///
/// ## Creating Advanced FSMs
///
/// A basic transducer would define an update function whose signature is
/// ```swift
/// (inout State, Event) -> Output
///```
/// where `Output` is just a value which can be used as a signal or an
/// input event for another FSM.
///
/// With that, you can implement a _Mealy_ and a _Moore_ machine, or a mix of
/// both.
///
/// Both, `State` and `Event` can carry associated data, which makes it
/// possibly to create more complex FSMs, socalled _extended FSMs_.
///
/// An even more sophisticated FSM can be defined, that creates _Effects_ as
/// part of the output. Effects are function objects, that will be invoked outside
/// the update function. Effects can be used to
///  - create events, that get sent back to the transducer,
///  - call functions (synchronously), that may cause side effects, and
///  may also send events to the transducer,
///  - call an async throwing function (operation), that may cause side effects, and
///  may also send one or more events to the transducer during their life-time,
///  - create Tasks with a unique id, that run an operation and that will be
///  managed by the transducer, so that they can be cancelled with another
///  effect, and that will be automatically cancelled when the transducer will
///  be terminated.
///
/// Side effects are any changes outside the system, i.e. changes that
/// mutate state located in the _World_, like I/O.
/// Side effects also may return events, or emit events during their
/// life-time, that get fed back into the transducer. Effects can also be
/// used to spawn other tranducers, aka "child transducers, that in
/// turn can spawn even more transducers. That way, its possible to
/// compose complex systems for complex problems.
///
/// This kind of transducer would define an update function whose signature
/// is
/// ```swift
/// (inout State, Event) -> (Effect?, TransducerOutput)
///```
///or, where the effect itself is the whole output:
/// ```swift
/// (inout State, Event) -> Effect?
///```
///
/// The TransducerOutput can be used to connect FSM's. For example, in hierarchically
/// nested or composite states, the child FSM emits events to its output, that
/// it does not handle itself. Previously, the parent FSM, that is responsible
/// to create the child FSM, has setup the output closure such, that it routes
/// the even to itself, where it can be handled. The parent knows the type of
/// the child's output type, so that it can map relevant events to its own event
/// type.
///
public protocol Transducer: SendableMetatype {
    /// The type of the state.
    associatedtype State: Terminable & SendableMetatype
    /// The type of the Input value.
    associatedtype Event: Sendable
    /// The type of the return value of the `update` function.
    associatedtype TransducerOutput
    /// The type of the environment. It must be defined when the transducer defines effects in its output.
    associatedtype Env = Never
    /// The type of the output value
    associatedtype Output = Never
    
    /// A proxy is a representation of a transducer. It's used to send events into
    /// its associated transducer.
    typealias Proxy = Oak.Proxy<Event>
    
    /// The combined _transition_ and _output_ function of the FSM. This function will be isolated on the caller's actor.
    static func update(_ state: inout State, event: sending Event) -> TransducerOutput
}

/// A conforming type that can be in a _terminal mode_.
///
/// An object is said to be in a terminal mode, when it is not reacting
/// to any inputs anymore and its state will not change.
public protocol Terminable {
    /// Returns `true` if `Self` is in a terminal mode.
    var isTerminal: Bool { get }
}

extension Terminable {
    public var isTerminal: Bool { false }
}

// MARK: - Errors

// Thrown when the computation will be called when the transducer is already terminated
struct TerminalStateError: Swift.Error {
    let message: String
}

// Thrown when the proxy is already associated to another transducer.
struct ProxyAlreadyAssociatedError: Swift.Error {
    let message: String = "Proxy already associated to another transducer"
}

// Thrown when the transducer terminated but has not produced an output.
struct TransducerDidNotProduceAnOutputError: Swift.Error {}

// MARK: - Implementations

extension Transducer where Env == Never {

    /// Creates a transducer whose update function has the signature
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function and the `output` closure are isolated by the given Actor, that
    /// can be explicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function must at least run once, in order to successfully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - storage: The underlying backing store for the state. Its type must conform to `Storage<State>`.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - out: A type conforming to `Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    package static func run(
        isolated: isolated any Actor = #isolation,
        storage: some Storage<State>,
        proxy: Proxy,
        out: some Subject<Output>,
        initialOutput: sending Output? = nil
    ) async throws -> Output where Output == TransducerOutput, Env == Never {
        guard proxy.continuation.onTermination == nil else {
            throw ProxyAlreadyAssociatedError()
        }
        proxy.continuation.onTermination = { _ in }
        var result: Output?
        if let initialOutput {
            try await out.send(initialOutput)
        }
        if !storage.value.isTerminal {
            loop: for try await transducerEvent in proxy.input {
                if case .event(let event) = transducerEvent {
                    let outputValues = compute(state: &storage.value, event: event, proxy: proxy)
                    try await out.send(outputValues)
                    if storage.value.isTerminal {
                        result = outputValues
                        proxy.continuation.finish()
                        break loop
                    }
                }
            }
        } else {
            proxy.continuation.finish()
            if let initialOutput {
                result = initialOutput
            }
        }
        var ignoreCount = 0
        for try await event in proxy.input {
            ignoreCount += 1
            logger.warning("Ignored an event (\(ignoreCount)) (aka '\(String("\(event)"))') because the transducer '\(Self.self)' is in a terminal state.")
        }
        try Task.checkCancellation() // we do throw on a Task cancellation, even in the case the FST is finished and we have a result!
        guard let result else {
            throw TransducerDidNotProduceAnOutputError()
        }
        return result
    }
    
    /// Creates a transducer whose update function has the signature
    /// `(inout State, Event) -> Void`.
    ///
    /// The update function are isolated by the given Actor, that
    /// can be explicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function must at least run once, in order to successfully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - storage: The underlying backing store for the state. Its type must conform to `Storage<State>`.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    package static func run(
        isolated: isolated any Actor = #isolation,
        storage: some Storage<State>,
        proxy: Proxy,
    ) async throws -> Void where TransducerOutput == Void, Env == Never {
        guard proxy.continuation.onTermination == nil else {
            throw ProxyAlreadyAssociatedError()
        }
        proxy.continuation.onTermination = { _ in }
        if !storage.value.isTerminal {
            loop: for try await transducerEvent in proxy.input {
                if case .event(let event) = transducerEvent {
                    compute(state: &storage.value, event: event, proxy: proxy)
                    if storage.value.isTerminal {
                        proxy.continuation.finish()
                        break loop
                    }
                }
            }
        } else {
            proxy.continuation.finish()
        }
        var ignoreCount = 0
        for try await event in proxy.input {
            ignoreCount += 1
            logger.warning("Ignored an event (\(ignoreCount)) (aka '\(String("\(event)"))') because the transducer '\(Self.self)' is in a terminal state.")
        }
        try Task.checkCancellation() // we do throw on a Task cancellation, even in the case the FST is finished and we have a result!
    }



    /// Creates a transducer with a strictly encapsulated state whose update function has the signature
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function and the `output` closure are isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - initialState: The inittial state of the transducer.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - out: A type conforming to `Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run(
        isolated: isolated any Actor = #isolation,
        initialState: sending State,
        proxy: Proxy,
        out: some Subject<Output>,
        initialOutput: sending Output? = nil
    ) async throws -> Output where Output == TransducerOutput, Env == Never {
        try await run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            out: out,
            initialOutput: initialOutput
        )
    }
    
    /// Creates a transducer with a strictly encapsulated state whose update function has the signature
    /// `(inout State, Event) -> Void`.
    ///
    /// The update function is isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - initialState: The inittial state of the transducer.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    public static func run(
        isolated: isolated any Actor = #isolation,
        initialState: sending State,
        proxy: Proxy
    ) async throws -> Void where Output == Never, TransducerOutput == Void, Env == Never {
        try await run(
            storage: LocalStorage(value: initialState),
            proxy: proxy
        )
    }
    
    /// Creates a transducer with a strictly encapsulated state whose update function has the signature
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function is isolated by the given Actor, that can be exlicitly specified, or it will be
    /// inferred from the caller. If it's not specified, and the caller is not isolated, the compilation will fail.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - initialState: The inittial state of the transducer.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run(
        isolated: isolated any Actor = #isolation,
        initialState: sending State,
        proxy: Proxy
    ) async throws -> Output where Output == TransducerOutput, Env == Never {
        try await run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            out: NoCallbacks<Output>()
        )
    }
    
    /// Creates a transducer with an observable state whose update function has the signature
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function and the `output` closure are isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - state: A reference-writeable key path to the state.
    ///   - host: The host providing the backing store for the state.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - out: A type conforming to `Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run<Host>(
        isolated: isolated any Actor = #isolation,
        state: ReferenceWritableKeyPath<Host, State>,
        host: Host,
        proxy: Proxy,
        out: some Subject<Output>,
        initialOutput: sending Output? = nil
    ) async throws -> Output where Output == TransducerOutput, Env == Never {
        try await run(
            storage: ReferenceKeyPathStorage(host: host, keyPath: state),
            proxy: proxy,
            out: out,
            initialOutput: initialOutput
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
        isolated: isolated any Actor = #isolation,
        state: ReferenceWritableKeyPath<Host, State>,
        host: Host,
        proxy: Proxy
    ) async throws -> Output where Output == TransducerOutput, Env == Never {
        try await run(
            storage: ReferenceKeyPathStorage(host: host, keyPath: state),
            proxy: proxy,
            out: NoCallbacks<Output>()
        )
    }

}

extension Transducer where TransducerOutput == (Oak.Effect<Self>?, Output) {
    
    /// Creates a transducer whose update function has the signature
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure are isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - storage: The underlying backing store for the state. Its type must conform to `Storage<State>`.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    ///   - out: A type conforming to `Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    package static func run(
        isolated: isolated any Actor = #isolation,
        storage: some Storage<State>,
        proxy: Proxy,
        env: Env,
        out: some Subject<Output>,
        initialOutput: sending Output? = nil,
    ) async throws -> Output where Self.TransducerOutput == (Oak.Effect<Self>?, Output), Output: Sendable {
        // TODO: there's a potential race condition when accessing `onTermination` in case the proxy will be used for multiple transducers at the same time. This is illegal according the documentation, though.
        guard proxy.continuation.onTermination == nil else {
            throw ProxyAlreadyAssociatedError()
        }
        proxy.continuation.onTermination = { _ in }
        
        let context = Context()
        defer {
            context.cancelAll()
        }
        var result: Output?
        if let initialOutput {
            try await out.send(initialOutput)
        }
        if !storage.value.isTerminal {
            loop: for try await event in proxy.input {
                switch event {
                case .event(let event):
                    let outputValues = compute(
                        state: &storage.value,
                        event: event,
                        proxy: proxy,
                        context: context,
                        env: env
                    )
                    try await out.send(outputValues)
                    if storage.value.isTerminal {
                        result = outputValues
                        proxy.continuation.finish()
                        break loop
                    }
                case .control(let control):
                    switch control {
                    case .cancelAllTasks:
                        context.cancelAll()
                    case .cancelTask(let taskId):
                        context.cancelTask(id: taskId)
                    case .dumpTasks:
                        break
                    }
                }
            }
        } else {
            proxy.continuation.finish()
            if let initialOutput {
                result = initialOutput
            }
        }
        var ignoreCount = 0
        for try await event in proxy.input {
            ignoreCount += 1
            logger.warning("Ignored an event (\(ignoreCount)) (aka '\(String("\(event)"))') because the transducer '\(Self.self)' is in a terminal state.")
        }
        try Task.checkCancellation() // we do throw on a Task cancellation, even in the case the FST is finished and we have a result!
        guard let result else {
            throw TransducerDidNotProduceAnOutputError()
        }
        return result
    }
}

extension Transducer where TransducerOutput == Oak.Effect<Self>? {
    
    /// Creates a transducer whose update function has the signature
    /// `(inout State, Event) -> Effect?`.
    ///
    /// The update function and the `output` closure are isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - storage: The underlying backing store for the state. Its type must conform to `Storage<State>`.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    package static func run(
        isolated: isolated any Actor = #isolation,
        storage: some Storage<State>,
        proxy: Proxy,
        env: Env,
    ) async throws -> Void where Self.TransducerOutput == Oak.Effect<Self>?, Output == Never {
        guard proxy.continuation.onTermination == nil else {
            throw ProxyAlreadyAssociatedError()
        }
        proxy.continuation.onTermination = { _ in }
        let context = Context()
        defer {
            context.cancelAll()
        }
        if !storage.value.isTerminal {
            loop: for try await event in proxy.input {
                switch event {
                case .event(let event):
                    compute(
                        state: &storage.value,
                        event: event,
                        proxy: proxy,
                        context: context,
                        env: env
                    )
                    if storage.value.isTerminal {
                        proxy.continuation.finish()
                        break loop
                    }
                case .control(let control):
                    switch control {
                    case .cancelAllTasks:
                        context.cancelAll()
                    case .cancelTask(let taskId):
                        context.cancelTask(id: taskId)
                    case .dumpTasks:
                        break
                    }
                }
            }
        } else {
            proxy.continuation.finish()
        }
        var ignoreCount = 0
        for try await event in proxy.input {
            ignoreCount += 1
            logger.warning("Ignored an event (\(ignoreCount)) (aka '\(String("\(event)"))') because the transducer '\(Self.self)' is in a terminal state.")
        }
        try Task.checkCancellation() // we do throw on a Task cancellation, even in the case the FST is finished!
    }
}

extension Transducer where TransducerOutput == (Oak.Effect<Self>?, Output) {
    
    /// Creates a transducer with a stricly encapsulated state whose update function has the signature
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure are isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - initialState: The inittial state of the transducer.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    ///   - out: A type conforming to `Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run(
        isolated: isolated any Actor = #isolation,
        initialState: sending State,
        proxy: Proxy,
        env: Env,
        out: some Subject<Output>,
        initialOutput: sending Output? = nil,
    ) async throws -> Output where Self.TransducerOutput == (Oak.Effect<Self>?, Output), Output: Sendable {
        try await run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            env: env,
            out: out,
            initialOutput: initialOutput
        )
    }
    
    /// Creates a transducer with a stricly encapsulated state whose update function has the signature
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure are isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - initialState: The inittial state of the transducer.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run(
        isolated: isolated any Actor = #isolation,
        initialState: sending State,
        proxy: Proxy,
        env: Env
    ) async throws -> Output where Self.TransducerOutput == (Oak.Effect<Self>?, Output), Output: Sendable {
        try await run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            env: env,
            out: NoCallbacks<Output>()
        )
    }
}

extension Transducer where TransducerOutput == Oak.Effect<Self>? {
    
    /// Creates a transducer with a stricly encapsulated state whose update function has the signature
    /// `(inout State, Event) -> Effect?`.
    ///
    /// The update function is isolated by the given Actor, that can be exlicitly specified, or it will be
    /// inferred from the caller. If it's not specified, and the caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - initialState: The inittial state of the transducer.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    public static func run(
        isolated: isolated any Actor = #isolation,
        initialState: sending State,
        proxy: Proxy,
        env: Env
    ) async throws -> Void where Self.TransducerOutput == Oak.Effect<Self>?, Output == Never {
        try await run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            env: env
        )
    }
}
    extension Transducer {

    /// Creates a transducer with an observable state whose update function has the signature
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure are isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - state: A reference-writeable key path to the state.
    ///   - host: The host providing the backing store for the state.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    ///   - out: A type conforming to `Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller or must not be used with any other transducer.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run<Host>(
        isolated: isolated any Actor = #isolation,
        state: ReferenceWritableKeyPath<Host, State>,
        host: Host,
        proxy: Proxy,
        env: Env,
        out: some Subject<Output>,
        initialOutput: sending Output? = nil
    ) async throws -> Output where Self.TransducerOutput == (Oak.Effect<Self>?, Output), Output: Sendable {
        try await run(
            storage: ReferenceKeyPathStorage(host: host, keyPath: state),
            proxy: proxy,
            env: env,
            out: out,
            initialOutput: initialOutput
        )
    }
    
    /// Creates a transducer with an observable state whose update function has the signature
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure are isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - state: A reference-writeable key path to the state.
    ///   - host: The host providing the backing store for the state.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run<Host>(
        isolated: isolated any Actor = #isolation,
        state: ReferenceWritableKeyPath<Host, State>,
        host: Host,
        proxy: Proxy,
        env: Env
    ) async throws -> Output where Self.TransducerOutput == (Oak.Effect<Self>?, Output), Output: Sendable {
        try await run(
            storage: ReferenceKeyPathStorage(host: host, keyPath: state),
            proxy: proxy,
            env: env,
            out: NoCallbacks()
        )
    }
    
    /// Creates a transducer with an observable state whose update function has the signature
    /// `(inout State, Event) -> Effect?`.
    ///
    /// The update function is isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function can be designed to optionally return an _effect_. Effects are invoked by
    /// the transducer which usually run within a Swift Task which is managed by the transuder. The tasks
    /// operation can emit events which will be feed back to the transducer. The managed tasks can
    /// be explicitly cancelled in the update function. When the transducer reaches a terminal state _all_
    /// running tasks will be cancelled.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - state: A reference-writeable key path to the state.
    ///   - host: The host providing the backing store for the state.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    public static func run<Host>(
        isolated: isolated any Actor = #isolation,
        state: ReferenceWritableKeyPath<Host, State>,
        host: Host,
        proxy: Proxy,
        env: Env
    ) async throws -> Void where Self.TransducerOutput == Oak.Effect<Self>?, Output == Never {
        try await run(
            storage: ReferenceKeyPathStorage(host: host, keyPath: state),
            proxy: proxy,
            env: env
        )
    }

}
 
// MARK: - Internal

extension Transducer where Env == Never {
    internal static func compute(
        state: inout State,
        event: Event,
        proxy: Proxy
    ) -> TransducerOutput {
        guard !state.isTerminal else {
            fatalError("Could not process event '\(event)' because the transducer (\(proxy.id.uuidString)) is already terminated.")
        }
        let transducerOutput = update(&state, event: event)
        return transducerOutput
    }
}

extension Transducer {
    internal static func compute(
        isolated: isolated any Actor = #isolation,
        state: inout State,
        event: Event,
        proxy: Proxy,
        context: Context,
        env: Env
    ) -> Output where Self.TransducerOutput == (Oak.Effect<Self>?, Output) {
        guard !state.isTerminal else {
            fatalError("Could not process event \(event) because the transducer (\(proxy.id.uuidString)) is already terminated.")
        }
        let transducerOutput = update(&state, event: event)
        if let effect = transducerOutput.0 {
            executeEffect(
                effect,
                proxy: proxy,
                context: context,
                env: env
            )
        }
        return transducerOutput.1
    }
}

extension Transducer where TransducerOutput == Oak.Effect<Self>? {
    internal static func compute(
        isolated: isolated any Actor = #isolation,
        state: inout State,
        event: Event,
        proxy: Proxy,
        context: Context,
        env: Env
    ) -> Void {
        guard !state.isTerminal else {
            fatalError("Could not process event \(event) because the transducer (\(proxy.id.uuidString)) is already terminated.")
        }
        let transducerOutput = update(&state, event: event)
        if let effect = transducerOutput {
            executeEffect(
                effect,
                proxy: proxy,
                context: context,
                env: env
            )
        }
    }
}

extension Transducer {
    internal static func executeEffect(
        isolated: isolated any Actor = #isolation,
        _ effect: Oak.Effect<Self>,
        proxy: Proxy,
        context: Context,
        env: Env
    ) {
        // Note, that an effect invocation may synchronously run its
        // operation, that may send one or more events to the transducer
        // via its proxy. When run synchronously, it returns `nil`. That
        // means, it ran its operation synchronously without wrapping
        // it in a Swift.Task. When events get produced synchronously,
        // and sent via the proxy, they need to be buffered in order to
        // prevent to re-enter the update function. In the current
        // implementation, the proxy uses an AsyncStream that provides
        // this buffer. The size of the buffer can be specified at the
        // time when the proxy will be created.
        effect.invoke(with: env, proxy: proxy, context: context)
    }
    
    private static func terminate(_ proxy: Proxy, reason: Swift.Error) {
        proxy.terminate(failure: reason)
    }
}


// MARK: - Internal

struct TaskID: @unchecked Sendable, Hashable {
    private let wrapped: AnyHashable
    
    init(_ wrapped: some Hashable & Sendable) {
        self.wrapped = .init(wrapped)
    }
}

internal final class Context {
    typealias ID = Int
    typealias UID = Int
    
    private var tasks: Dictionary<TaskID, (UID, Task<Void, Never>)> = [:]
    var id: ID = 0
    var uid: UID = 0

    @usableFromInline
    func removeCompleted(id: some Hashable & Sendable, uid: UID) {
        let id = TaskID(id)
        if let entry = tasks[id], entry.0 == uid {
            tasks.removeValue(forKey: id)
        }
    }
    
    @usableFromInline
    func register(id: some Hashable & Sendable, uid: UID, task: Task<Void, Never>) {
        let id = TaskID(id)
        if let previousTask = tasks[id] {
            previousTask.1.cancel()
        }
        tasks[id] = (uid, task)
    }

    @usableFromInline
    func register(uid: UID, task: Task<Void, Never>) -> TaskID {
        let id = TaskID(uniqueID())
        if let previousTask = tasks[id] {
            previousTask.1.cancel()
        }
        tasks[id] = (uid, task)
        return id
    }

    func cancelAll() {
        tasks.values.forEach {
            $0.1.cancel()
        }
    }
    
    func cancelTask(id: TaskID) {
        if let task = tasks[id] {
            task.1.cancel()
        }
    }
    
    @usableFromInline
    func uniqueID() -> ID {
        defer { id += 1 }
        return id
    }
    
    @usableFromInline
    func uniqueUID() -> UID {
        defer { uid += 1 }
        return uid
    }
}


// MARK: - Internal Storage

package protocol Storage<Value> {
    associatedtype Value
    
    var value: Value { get nonmutating set }
    
    func lock()
    func unlock()
}

package extension Storage {
    // Default is no-op
    func lock() {}
    // Default is no-op
    func unlock() {}
}

internal struct LocalStorage<Value>: Storage {
    final class Reference {
        var value: Value

        init(value: sending Value) {
            self.value = value
        }
    }
    
    init(value: sending Value) {
        storage = Reference(value: value)
    }
    
    private let storage: Reference
    
    var value: Value {
        get {
            storage.value
        }
        nonmutating set {
            storage.value = newValue
        }
    }
}


// See also: https://forums.swift.org/t/keypath-performance/60487/2
internal struct ReferenceKeyPathStorage<Host, Value>: Storage {
    
    init(host: Host, keyPath: ReferenceWritableKeyPath<Host, Value>) {
        self.host = host
        self.keyPath = keyPath
    }
    
    private let host: Host
    private let keyPath: ReferenceWritableKeyPath<Host, Value>
    
    var value: Value {
        get {
            host[keyPath: keyPath]
        }
        nonmutating set {
            host[keyPath: keyPath] = newValue
        }
    }
}

