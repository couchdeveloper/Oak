/// A named function that encapsulates an operation.
///
/// An effect will be created in the _update_ function of the transducer.
/// The transducer immediately invokes the effect _after_ the update
/// function returns. This starts the operation. When invoking an effect,
/// the transducer passes a _proxy_ representing itself and an _env_
/// value, the _environment_.
///
/// The proxy is used by the operation running the side effect to send
/// events back to the transducer. The environment can be used to
/// provide dependencies and other information to the operation.
///
/// An Effect is used to access the outside world, for example calling
/// a network API, accesing a database and the like. For example, in
/// order to send an HTTP response to the transducer, the response
/// will be materialised as an event, and then sent to the transducer
/// via its proxy.
///
/// Depending on the way the effect has been created, the transducer
/// may manage the underlying Swift Task that executes the operation,
/// so that it can be cancelled on demand. These _managed_ effects
/// will also be automatically cancelled when the transducer will be
/// terminated or destroyed.
///
/// - TODO: `Effect` would benefit from being a noncopyable type.
/// However, currently noncopyable types cannot be used within a
/// variadic type.
public struct Effect<Event: Sendable, Env: Sendable>: Sendable /*, ~Copyable*/ {
    public typealias Event = Event
    public typealias Env = Env
        
    public typealias AnyProxy = any Oak.TransducerProxy<Event>

    internal typealias Proxy = Oak.Proxy<Event>
    internal typealias TaskProxy = EffectProxy<Event>

    private let f: @Sendable (Env, Proxy) -> [OakTask]?

    private init(f: @escaping @Sendable (Env, Proxy) -> [OakTask]?) {
        self.f = f
    }

    consuming func invoke(
        with env: Env,
        proxy: Proxy
    ) -> [OakTask]? {
        f(env, proxy)
    }
}

extension Effect where Env == Void {
    consuming func invoke(
        proxy: Proxy
    ) -> [OakTask]? {
        f(Void(), proxy)
    }
}

@globalActor actor MyGlobalActor: GlobalActor {
    static let shared = MyGlobalActor()
}


extension Effect {
    
    /// Returns an Effect that creates a managed Task with the given ID and the
    /// given asynchronous throwing operation.
    ///
    /// When invoked, the effect creates a `Swift.Task` executing the operation.
    /// When there is already an operation running with the same id, the existing
    /// operation will be cancelled.
    ///
    /// The `id` can be used in the transition function to explicitly cancel the
    /// operation, if needed.
    ///
    /// A managed task will be automatically cancelled when the transducer terminates.
    ///
    /// The operation receives an environment value, that can be used to obtain
    /// dependencies or other information. It also is given the proxy - that is the receiver
    /// of any events emitted by the operation.
    ///
    /// ### Example
    /// The below example shows how to create a timer effect:
    /// ```swift
    /// 
    /// ```
    /// When the operation will be cancelled in the transition function via returning
    /// a cancellation effect, the proxy will be invalidated so that events that will be
    /// produced by the operation will not be received by the transducer. The only
    /// time to have a still valid proxy is in a cancellation handler of a Task, where
    /// it would be possible to send events to the transducer.
    ///
    /// - Parameters:
    ///   - id: An ID that identifies this operation.
    ///   - operation: An async throwing function receiving the environment and the proxy
    ///     as parameter.
    public init(
        id: some Hashable & Sendable,
        operation: @escaping @isolated(any) @Sendable (Env, AnyProxy) async throws -> Void
    ) {
        self.f = { env, proxy in
            let taskProxy = EffectProxy(proxy: proxy)
            let task = Task {
                try await operation(env, taskProxy)
            }
            return [.init(id: id, task: task, taskProxy: taskProxy)]
        }
    }
    
    /// Returns an Effect that creates a managed Task for the given operation.
    ///
    /// When invoked, the effect creates a `Swift.Task` executing the operation.
    /// A managed task will be automatically cancelled when the transducer terminates.
    ///
    /// The operation receives an environment value, that can be used to obtain
    /// dependencies or other information. It also is given the proxy - that is the receiver
    /// of any events emitted by the operation.
    ///
    /// When the operation will be cancelled in the transition function via returning
    /// a cancellation effect, the proxy will be invalidated so that events that will be
    /// produced by the operation will not be received by the transducer. The only
    /// time to have a still valid proxy is in a cancellation handler of a Task, where
    /// it would be possible to send events to the transducer.
    ///
    /// - Parameters:
    ///   - operation: An async function receiving the environment and the proxy
    ///     as parameter.
    public init(
        operation: @escaping @isolated(any) @Sendable (Env, AnyProxy) async throws -> Void
    ) {
        self.f = { env, proxy in
            let taskProxy = EffectProxy(proxy: proxy)
            let task = Task {
                try await operation(env, taskProxy as AnyProxy)
            }
            return [.init(task: task, taskProxy: taskProxy)]
        }
    }

    /// Returns an Effect that creates a managed Task with the given ID and the
    /// operation.
    ///
    /// When invoked, the effect creates a `Swift.Task` executing the operation.
    /// When there is already an operation running with the same id, the existing
    /// operation will be cancelled.
    ///
    /// The `id` can be used in the transition function to explicitly cancel the
    /// operation, if needed.
    ///
    /// A managed task will be automatically cancelled when the transducer terminates.
    ///
    /// The operation receives an environment value, that can be used to obtain
    /// dependencies or other information. It also is given the proxy - that is the receiver
    /// of any events emitted by the operation.
    ///
    /// When the operation will be cancelled in the transition function via returning
    /// a cancellation effect, the proxy will be invalidated so that events that will be
    /// produced by the operation will not be received by the transducer. The only
    /// time to have a still valid proxy is in a cancellation handler of a Task, where
    /// it would be possible to send events to the transducer.
    ///
    /// - Parameters:
    ///   - id: A  value conforming to `Hashable & Sendable` that identifies this operation.
    ///   - operation: An async throwing function receiving the environment and the proxy
    ///     as parameter.
    ///  - Returns: An asynchronous effect.
    public static func task(
        _ id: some Hashable & Sendable,
        operation: @escaping @isolated(any) @Sendable (Env, AnyProxy) async throws -> Void
    ) -> Effect {
        Effect(id: id, operation: operation)
    }
    
    /// Rerturns an effect that runs the given closure `action(:_)` _synchronously_ on
    /// the Transducer's isolated domain.
    ///
    /// - Parameter action: The closure to run.
    /// - Returns: A synchronous effect.
    public static func action(
        _ action: @escaping @Sendable (Env, AnyProxy) -> Void
    ) -> Effect {
        Effect(f: { env, proxy in
            action(env, ActionProxy(proxy: proxy))
            return nil
        })
    }
    
    /// Returns an `Effect` value that when invoked, sends the given event
    /// synchronously to the transucer.
    ///
    /// - Parameter event: The event that should be sent to the transducer.
    /// - Returns: A synchronous effect.
    public static func event(_ event: Event) -> Effect {
        Effect { _, proxy in
            try? proxy.send(event) // TODO: Check how to handle the error
            return nil
        }
    }
    
    /// Returns an asynchronous effect that, when executed sends the specified event after the
    /// specified duration to the transducer.
    ///
    /// The `id` can be used in the transition function to explicitly cancel the
    /// intent, if needed.
    ///
    /// When there is already an operation running with the same id, the existing
    /// operation will be cancelled.
    ///
    /// A pending effect will be automatically cancelled when the transducer terminates.
    ///
    /// - Parameters:
    ///   - event: The event that will be sent to the transducer at deadline.
    ///   - id: A value conforming to `Hashable & Sendable` that identifies this intent. Unless
    ///   the event has already been sent to the transducer, it can be used to cancel this intent.
    ///   - duration: The duration after that the event should be sent to the transducer.
    ///   - tolerance: The a leeway around the deadline. If no tolerance is specified (i.e. nil is passed
    ///   in) the operation is expected to be scheduled with a default tolerance strategy.
    ///   - clock: A clock, conforming to protocol `Swift.Clock`.
    /// - Returns: An asynchronous effect.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    public static func event<C: Clock>(
        _ event: Event,
        id: some Hashable & Sendable,
        after duration: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = ContinuousClock()
    ) -> Effect {
        Effect(id: id) { env, proxy in
            try await Task.sleep(for: duration, tolerance: tolerance, clock: clock)
            try? proxy.send(event)
        }
    }

    /// Returns an asynchronous effect that, when executed after the specified duration, sends the
    /// specified event to the transducer.
    ///
    /// A pending effect will be automatically cancelled when the transducer terminates.
    ///
    /// - Parameters:
    ///   - event: The event that will be send to the transducer at deadline.
    ///   - duration: The duration after which the event should be sent to the transducer.
    ///   - tolerance: The a leeway around the deadline. If no tolerance is specified (i.e. nil is passed
    ///   in) the operation is expected to be scheduled with a default tolerance strategy.
    ///   - clock: A clock, conforming to protocol `Swift.Clock`.
    /// - Returns: An effect.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    public static func event<C: Clock>(
        _ event: Event,
        after duration: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = ContinuousClock()
    ) -> Effect {
        Effect { env, proxy in
            try await Task.sleep(for: duration, tolerance: tolerance, clock: clock)
            try? proxy.send(event)
        }
    }
    
    /// Returns a synchronous effect that when invoked, cancels the operation with the
    /// given ID.
    ///
    /// - Parameters:
    ///   - id: The ID of the operation that should be cancelled.
    ///
    /// - Returns: A synchronous effect.
    public static func cancelTask(
        _ id: some Hashable & Sendable
    ) -> Effect {
        Effect { _, proxy in
            try? proxy.cancelTask(TaskID(id))
            return nil
        }
    }
    
    /// Returns a synchronous effect that cancels all operations.
    ///
    /// - Returns: A synchronous effect.
    public static func cancelAllTasks() -> Effect {
        Effect { _, proxy in
            try? proxy.cancelAllTasks()
            return nil
        }
    }
    
    
    // TODO: fix when available: "Noncopyable type 'Effect<Event, Env>' cannot be used within a variadic type yet."
    public static func effects(_ effects: Effect...) -> Effect {
        Self.effects(effects)
    }
    
    public static func effects(_ effects: [Effect]) -> Effect {
        Effect { env, proxy in
            let oakTasks = effects.reduce(into: [OakTask]()) { a, effect in
                a.append(contentsOf: (effect.invoke(with: env, proxy: proxy) ?? []))
            }
            return oakTasks.isEmpty ? nil : oakTasks
        }
    }
}


struct OakTask {
    init(
        id: some Hashable & Sendable,
        task: Task<Void, Error>,
        taskProxy: (any Invalidable)?
    ) {
        self.id = TaskID(id)
        self.task = task
        self.proxy = taskProxy
    }
    
    init(task: Task<Void, Error>, taskProxy: (any Invalidable)?) {
        self.id = nil
        self.task = task
        self.proxy = taskProxy
    }
    
    let id: TaskID?
    var task: Task<Void, Error>
    let proxy: (any Invalidable)?
}


