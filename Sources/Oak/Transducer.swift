
/// A conforming type defines a concrete _model of computation_
/// or _abstract machine_ for an _extended_ Finite State Automaton (FSA).
///
/// A conforming type defines `State`, `Event`, `Output` and the
/// _update_ function for the FSA. The update function combines the _transition_
/// and _output_ function. These parts complete the definition of a
/// FSA or FST (Finite State Transducer).
///
/// A finite state transducer will be finally created and put into the initial state
/// with the protocol extension function `run()`. The function is async and
/// throwing. The function returns when the transducer's state transitioned to
/// a terminal state.
///
/// A FSA needs to run in an _isolated domain_, that needs to be provided
/// by the call-site. Isolation basically means, that the _state_ is _isolated_
/// and mutation of the state respects thread-safety. While this is an implementation
/// detail of an abstract machine, it is crucial for a correct implementation in
/// software within a concurrent environment. In Oak, the isolation will be
/// realised with an `Swift.Actor`.
///
/// A basic transducer would define an update function whose signature is
/// ```swift
/// (inout State, Event) -> Output
///```
/// With that, you can implement a _Mealy_ and a _Moore_ machine, or a mix of
/// both. Since `State` and `Event` can carry associated data, even more
/// complex machines are possible.
///
/// A more sophisticated transducer can be defined, that creates _Effects_ as
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
/// (inout State, Event) -> (Effect?, Output)
///```
///or, where the effect itself is the whole output:
/// ```swift
/// (inout State, Event) -> Effect?
///```
/// The Output can be used to connect FST's. For example, in hierarchically
/// nested or composite states, the child FST emits events to its output, that
/// it does not handle itself. Previously, the parent FST, that is responsible
/// to create the child FST, has setup the output closure such, that it routes
/// the even to itself, where it can be handled. The parent knows the type of
/// the child's output type, so that it can map relevant events to its own event
/// type.
///
public protocol Transducer {
    associatedtype State: Terminable
    associatedtype Event: Sendable
    associatedtype Output: Sendable
    associatedtype Env = Never
    
    typealias Proxy = Oak.Proxy<Event>
    
    /// The combined _transition_ and _output_ function of the FST. This function will be isolated on the caller's actor.
    static func update(_ state: inout State, event: Event) -> Output
}

public protocol Terminable {
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

// Thrown when the transducer terminated but has not produced an output.
struct TransducerDidNotProduceAnOutputError: Swift.Error {}

// MARK: - Implementations

extension Transducer where Env == Never {
    
    /// Creates a transducer with a strictly encapsulated state whose update function has the signatur
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - state: The backing store for the state which will be updated with the last state value when the function returns.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - out: A type conforming to `Oak.Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: Accessing the state variable concurrently will expose intermediate state and will inject mutated state. This may cause incorrect behaviour.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    public static func run(
        isolated: isolated any Actor = #isolation,
        state: inout State,
        proxy: Proxy,
        out: some Subject<Output>,
        initialOutput: Output? = nil
    ) async throws -> Output {
        var result: Output?
        if let initialOutput {
            try await out.send(initialOutput)
        }
        if !state.isTerminal {
            loop: for try await transducerEvent in proxy.input {
                if case .event(let event) = transducerEvent {
                    let outputValues = compute(state: &state, event: event, proxy: proxy)
                    try await out.send(outputValues)
                    if state.isTerminal {
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
    
    /// Creates a transducer with a strictly encapsulated state whose update function has the signatur
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function is isolated by the given Actor, that can be exlicitly specified, or it will be
    /// inferred from the caller. If it's not specified, and the caller is not isolated, the compilation will fail.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - state: The backing store for the state which will be updated with the last state value when the function returns.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    /// - Warning: Accessing the state variable concurrently will expose intermediate state and will inject mutated state. This may cause incorrect behaviour.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run(
        isolated: isolated any Actor = #isolation,
        state: inout State,
        proxy: Proxy
    ) async throws -> Output {
        try await run(
            state: &state,
            proxy: proxy,
            out: NoCallbacks<Output>()
        )
    }
}

extension Transducer where Env: Sendable {
    /// Creates a transducer whose update function has the signatur
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
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
    ///   - state: The backing store for the state which will be updated with the last state value when the function returns.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    ///   - out: A type conforming to `Oak.Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: Accessing the state variable concurrently will expose intermediate state and will inject mutated state. This may cause incorrect behaviour.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    public static func run<Output: Sendable>(
        isolated: isolated any Actor = #isolation,
        state: inout State,
        proxy: Proxy,
        env: Env,
        out: some Subject<Output>,
        initialOutput: Output? = nil,
    ) async throws -> Output where Self.Output == (Oak.Effect<Event, Env>?, Output) {
        let context = Context()
        defer {
            context.cancelAll()
        }
        var result: Output?
        if let initialOutput {
            try await out.send(initialOutput)
        }
        if !state.isTerminal {
            loop: for try await event in proxy.input {
                switch event {
                case .event(let event):
                    let outputValues = compute(
                        state: &state,
                        event: event,
                        proxy: proxy,
                        context: context,
                        env: env
                    )
                    try await out.send(outputValues)
                    if state.isTerminal {
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
    
    /// Creates a transducer with a stricly encapsulated state whose update function has the signatur
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
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
    ///   - state: The backing store for the state which will be updated with the last state value when the function returns.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    /// - Warning: Accessing the state variable concurrently will expose intermediate state and will inject mutated state. This may cause incorrect behaviour.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run<Output: Sendable>(
        isolated: isolated any Actor = #isolation,
        state: inout State,
        proxy: Proxy,
        env: Env
    ) async throws -> Output where Self.Output == (Oak.Effect<Event, Env>?, Output) {
        try await run(
            isolated: isolated,
            state: &state,
            proxy: proxy,
            env: env,
            out: NoCallbacks<Output>()
        )
    }
    
    /// Creates a transducer whose update function has the signatur
    /// `(inout State, Event) -> Effect?`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
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
    ///   - state: The backing store for the state which will be updated with the last state value when the function returns.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    /// - Warning: Accessing the state variable concurrently will expose intermediate state and will inject mutated state. This may cause incorrect behaviour.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    public static func run(
        isolated: isolated any Actor = #isolation,
        state: inout State,
        proxy: Proxy,
        env: Env,
    ) async throws -> Void where Self.Output == Oak.Effect<Event, Env>? {
        let context = Context()
        defer {
            context.cancelAll()
        }
        if !state.isTerminal {
            loop: for try await event in proxy.input {
                switch event {
                case .event(let event):
                    compute(
                        state: &state,
                        event: event,
                        proxy: proxy,
                        context: context,
                        env: env
                    )
                    if state.isTerminal {
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

extension Transducer where Env == Never {

    /// Creates a transducer whose update function has the signatur
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// The update function must at least run once, in order successully execute the transducer.
    /// The initial state must not be a terminal state.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - storage: The underlying backing store for the state. It's type must conform to `Oak.Storage<State>`.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - out: A type conforming to `Oak.Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    internal static func run(
        isolated: isolated any Actor = #isolation,
        storage: some Oak.Storage<State>,
        proxy: Proxy,
        out: some Subject<Output>,
        initialOutput: Output? = nil
    ) async throws -> Output {
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

    /// Creates a transducer with a strictly encapsulated state whose update function has the signatur
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - initialState: The inittial state of the transducer.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - out: A type conforming to `Oak.Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run(
        isolated: isolated any Actor = #isolation,
        initialState: State,
        proxy: Proxy,
        out: some Subject<Output>,
        initialOutput: Output? = nil
    ) async throws -> Output {
        try await run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            out: out,
            initialOutput: initialOutput
        )
    }
    
    /// Creates a transducer with a strictly encapsulated state whose update function has the signatur
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
        initialState: State,
        proxy: Proxy
    ) async throws -> Output {
        try await run(
            initialState: initialState,
            proxy: proxy,
            out: NoCallbacks<Output>()
        )
    }
    
    /// Creates a transducer with an observable state whose update function has the signatur
    /// `(inout State, Event) -> Output`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
    /// can be exlicitly specified, or it will be inferred from the caller. If it's not specified, and the
    /// caller is not isolated, the compilation will fail.
    ///
    /// - Parameters:
    ///   - isolated: The actor where the `update` function will run on and where the state
    ///   will be mutated.
    ///   - state: A reference-writeable key path to the state.
    ///   - host: The host providing the backing store for the state.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - out: A type conforming to `Oak.Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
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
        out: some Subject<Output>,
        initialOutput: Output? = nil
    ) async throws -> Output {
        try await run(
            storage: ReferenceKeyPathStorage(host: host, keyPath: state),
            proxy: proxy,
            out: out,
            initialOutput: initialOutput
        )
    }
    
    /// Creates a transducer with an observable state whose update function has the signatur
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
    /// - Warning: The backing store for the state variable must not be mutated by the caller.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run<Host>(
        isolated: isolated any Actor = #isolation,
        state: ReferenceWritableKeyPath<Host, State>,
        host: Host,
        proxy: Proxy
    ) async throws -> Output {
        try await run(
            isolated: isolated,
            state: state,
            host: host,
            proxy: proxy,
            out: NoCallbacks<Output>()
        )
    }

}

extension Transducer where Env: Sendable {

    /// Creates a transducer whose update function has the signatur
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
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
    ///   - storage: The underlying backing store for the state. It's type must conform to `Oak.Storage<State>`.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    ///   - out: A type conforming to `Oak.Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    internal static func run<Output: Sendable>(
        isolated: isolated any Actor = #isolation,
        storage: some Oak.Storage<State>,
        proxy: Proxy,
        env: Env,
        out: some Subject<Output>,
        initialOutput: Output? = nil,
    ) async throws -> Output where Self.Output == (Oak.Effect<Event, Env>?, Output) {
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
    
    /// Creates a transducer whose update function has the signatur
    /// `(inout State, Event) -> Effect?`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
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
    ///   - storage: The underlying backing store for the state. It's type must conform to `Oak.Storage<State>`.
    ///   - proxy: The proxy, that will be associated to the transducer as its agent.
    ///   - env: An environment value. The environment value will be passed as an argument to an `Effect`s' `invoke` function.
    /// - Warning: The backing store for the state variable must not be mutated by the caller.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    internal static func run(
        isolated: isolated any Actor = #isolation,
        storage: some Oak.Storage<State>,
        proxy: Proxy,
        env: Env,
    ) async throws -> Void where Self.Output == Oak.Effect<Event, Env>? {
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

    
    /// Creates a transducer with a stricly encapsulated state whose update function has the signatur
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
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
    ///   - out: A type conforming to `Oak.Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run<Output: Sendable>(
        isolated: isolated any Actor = #isolation,
        initialState: State,
        proxy: Proxy,
        env: Env,
        out: some Subject<Output>,
        initialOutput: Output? = nil,
    ) async throws -> Output where Self.Output == (Oak.Effect<Event, Env>?, Output) {
        try await run(
            storage: LocalStorage(value: initialState),
            proxy: proxy,
            env: env,
            out: out,
            initialOutput: initialOutput
        )
    }
    
    /// Creates a transducer with a stricly encapsulated state whose update function has the signatur
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
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
    public static func run<Output: Sendable>(
        isolated: isolated any Actor = #isolation,
        initialState: State,
        proxy: Proxy,
        env: Env
    ) async throws -> Output where Self.Output == (Oak.Effect<Event, Env>?, Output) {
        try await run(
            isolated: isolated,
            initialState: initialState,
            proxy: proxy,
            env: env,
            out: NoCallbacks<Output>()
        )
    }

    /// Creates a transducer with an observable state whose update function has the signatur
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
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
    ///   - out: A type conforming to `Oak.Subject<Output>` where the transducer sends the output it produces. The client uses a type where it can react on the given outputs.
    ///   - initialOutput: The output value which – when not `nil` – will be produced by the transducer when setting its initial state.Note: an initial output value is required when implementing a _Mealy_ automaton.
    /// - Returns: The output, that has been generated when the transducer reaches a terminal state.
    /// - Warning: The backing store for the state variable must not be mutated by the caller.
    /// - Throws: Throws an error indicating the reason, for example, when the Swift Task, where the
    /// transducer is running on, has been cancelled, or when it has been forcibly terminated, and thus could
    /// not reach a terminal state.
    @discardableResult
    public static func run<Output: Sendable, Host>(
        isolated: isolated any Actor = #isolation,
        state: ReferenceWritableKeyPath<Host, State>,
        host: Host,
        proxy: Proxy,
        env: Env,
        out: some Subject<Output>,
        initialOutput: Output? = nil
    ) async throws -> Output where Self.Output == (Oak.Effect<Event, Env>?, Output) {
        try await run(
            storage: ReferenceKeyPathStorage(host: host, keyPath: state),
            proxy: proxy,
            env: env,
            out: out,
            initialOutput: initialOutput
        )
    }
    
    /// Creates a transducer with an observable state whose update function has the signatur
    /// `(inout State, Event) -> (Effect?, Output)`.
    ///
    /// The update function and the `output` closure is isolated by the given Actor, that
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
    public static func run<Output: Sendable, Host>(
        isolated: isolated any Actor = #isolation,
        state: ReferenceWritableKeyPath<Host, State>,
        host: Host,
        proxy: Proxy,
        env: Env
    ) async throws -> Output where Self.Output == (Oak.Effect<Event, Env>?, Output) {
        try await run(
            isolated: isolated,
            state: state,
            host: host,
            proxy: proxy,
            env: env,
            out: NoCallbacks()
        )
    }
}
 
// MARK: - Internal

extension Transducer where Env == Never {
    internal static func compute(
        state: inout State,
        event: Event,
        proxy: Proxy
    ) -> Output {
        guard !state.isTerminal else {
            fatalError("Could not process event '\(event)' because the transducer (\(proxy.id.uuidString)) is already terminated.")
        }
        let transducerOutput = update(&state, event: event)
        return transducerOutput
    }
}

extension Transducer where Env: Sendable {
    internal static func compute<Output>(
        isolated: isolated any Actor = #isolation,
        state: inout State,
        event: Event,
        proxy: Proxy,
        context: Context,
        env: Env
    ) -> Output where Self.Output == (Oak.Effect<Event, Env>?, Output) {
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

extension Transducer where Output == Oak.Effect<Event, Env>?, Env: Sendable {
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

extension Transducer where Env: Sendable {
    internal static func executeEffect(
        isolated: isolated any Actor = #isolation,
        _ effect: Oak.Effect<Event, Env>,
        proxy: Proxy,
        context: Context,
        env: Env
    ) {
        func onCompletion(
            isolated: isolated any Actor,
            oakTask: OakTask,
            result: Result<Void, Error>
        ) {
            context.removeCompleted(oakTask: oakTask)
            if case .failure(let error) = result, !(error is CancellationError) {
                terminate(proxy, reason: error)
            }
        }
        
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
        if let oakTasks = effect.invoke(with: env, proxy: proxy) {
            oakTasks.forEach { oakTask in
                let oakTask = context.register(oakTask)
                Task {
                    let result = await oakTask.task.result
                    // This suspends on 'isolated' because onCompletion has
                    // `isolated: isolated any Actor` parameter. Due to this,
                    //  we can call onCompletion synchronously.
                    onCompletion(isolated: isolated, oakTask: oakTask, result: result)
                }
            }
        }
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
    private var tasks: Dictionary<TaskID, (task: Task<Void, Error>, proxy: (any Invalidable)?)> = [:]
    typealias ID = Int
    var id: ID = 0
    
    @usableFromInline
    func removeCompleted(oakTask: OakTask) {
        if let id = oakTask.id, let value = tasks[id], oakTask.task == value.task {
            tasks.removeValue(forKey: id)
        }
    }
    
    @usableFromInline
    func register(_ oakTask: OakTask) -> OakTask {
        let task = oakTask.task
        if let id = oakTask.id {
            if let previousTask = tasks[id] {
                previousTask.task.cancel()
                previousTask.proxy?.invalidate()
            }
            tasks[id] = (task: task, proxy: oakTask.proxy)
            return oakTask
        } else {
            let id = TaskID(uniqueId())
            tasks[id] = (task: task, proxy: oakTask.proxy)
            return OakTask(id: id, task: task, taskProxy: oakTask.proxy)
        }
    }
    
    func cancelAll() {
        tasks.values.forEach {
            $0.task.cancel()
            $0.proxy?.invalidate()
        }
    }
    
    func cancelTask(id: TaskID) {
        if let task = tasks[id] {
            task.task.cancel()
            task.proxy?.invalidate()
        }
    }
    
    @usableFromInline
    func uniqueId() -> ID {
        defer { id += 1 }
        return id
    }
}


// MARK: - Internal Storage

internal protocol Storage<Value> {
    associatedtype Value
    
    var value: Value { get nonmutating set }
    
    func lock()
    func unlock()
}

extension Storage {
    // Default is no-op
    func lock() {}
    // Default is no-op
    func unlock() {}
}

internal struct LocalStorage<Value>: Storage {
    final class Reference {
        var value: Value

        init(value: Value) {
            self.value = value
        }
    }
    
    init(value: Value) {
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

