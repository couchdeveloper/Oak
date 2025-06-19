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
    public typealias Proxy = Oak.Proxy<Event>

    private let f: @Sendable (Env, Proxy, Context, isolated any Actor) -> Void

    private init(f: @escaping @Sendable (Env, Proxy, Context, isolated any Actor) -> Void) {
        self.f = f
    }

    consuming func invoke(
        isolated: isolated any Actor = #isolation,
        with env: Env,
        proxy: Proxy,
        context: Oak.Context
    ) {
        f(env, proxy, context, isolated)
    }
}

extension Effect where Env == Void {
    consuming func invoke(
        isolated: isolated any Actor = #isolation,
        proxy: Proxy,
        context: Oak.Context
    ) {
        f(Void(), proxy, context, isolated)
    }
}

extension Effect {
    
    /// Returns an Effect that when invoked creates a managed Task with the given ID
    /// that executes the given asynchronous throwing operation.
    ///
    /// When there is already an operation running with the same id, the existing
    /// operation will be cancelled.
    ///
    /// The `id` can be used in the transition function in order to _explicitly_ cancel
    /// the operation, if needed.
    ///
    /// A managed task will be automatically cancelled when the transducer terminates.
    ///
    /// The operation receives an environment value, that can be used to obtain
    /// dependencies or other information. It also is given the proxy - that is the receiver
    /// of any events emitted by the operation.
    ///
    /// ### Example
    ///
    /// The below example shows how to create a simple timer effect:
    /// ```swift
    /// static let timer = Effect(id: "timer") { env, proxy in
    ///     while true {
    ///         try await Task.sleep(nanoseconds: 1_000_000_000)
    ///         try? proxy.send(.ping)
    ///     }
    /// }
    /// ```
    ///
    /// The operation above will be executed within a Swift Task which is managed
    /// by the transducer.
    ///
    /// The timer can be cancelled within the `update` function by returning a
    /// _cancellation_ effect, a static function `cancelTask(_:)`, which requires
    /// the `id` of the effect as a parameter when it has been created:
    ///```swift
    /// static func update(
    ///     _ state: inout State,
    ///     event: Event
    /// ) -> Effect? {
    ///     ...
    ///     case (.stopTimer, .running):
    ///         return .cancelTask("timer")
    ///     ...
    ///```
    /// The cancellation effect will cancel the Swift Task which executes the
    /// operation. Once the Task has been cancelled, the proxy in the above
    /// timer operation cannot send events to the transducer anymore.
    ///
    /// - Parameters:
    ///   - id: An ID that identifies this operation.
    ///   - operation: An async throwing function receiving the environment and the proxy
    ///     as parameter.
    ///   - priority: The priority of the task. Pass `nil` to use the priority from `Task.currentPriority`.
    public init(
        id: some Hashable & Sendable,
        operation: @escaping @isolated(any) @Sendable (
            Env,
            Proxy
        ) async throws -> Void,
        priority: TaskPriority? = nil
    ) {
        self.f = { env, proxy, context, isolated in
            let uid = context.uniqueUID()
            let task = Task.init(priority: priority) {
                do {
                    try await operation(env, proxy)
                } catch is CancellationError {
                } catch {
                    proxy.terminate(failure: error)
                }
                Self.removeCompletedTask(
                    id: id,
                    uid: uid,
                    context: context,
                    isolated: isolated
                )
            }
            context.register(id: id, uid: uid, task: task)
        }
    }
    
    /// Returns an Effect that when invoked creates a managed Task that executes
    /// the given asynchronous throwing operation.
    ///
    /// The managed task will be automatically cancelled when the transducer terminates.
    ///
    /// The operation receives an environment value, that can be used to obtain
    /// dependencies or other information. It also is given the proxy - that is the receiver
    /// of any events emitted by the operation.
    ///
    /// - Parameters:
    ///   - operation: An async function receiving the environment and the proxy
    ///     as parameter.
    ///   - priority: The priority of the task. Pass `nil` to use the priority from `Task.currentPriority`.
    public init(
        operation: @escaping @isolated(any) @Sendable (
            Env,
            Proxy
        ) async throws -> Void,
        priority: TaskPriority? = nil
    ) {
        self.f = { env, proxy, context, isolated in
            let id = context.uniqueUID()
            let task = Task(priority: priority) {
                do {
                    try await operation(env, proxy)
                } catch is CancellationError {
                } catch {
                    proxy.terminate(failure: error)
                }
                Self.removeCompletedTask(
                    id: id,
                    uid: 0,
                    context: context,
                    isolated: isolated
                )
            }
            context.register(id: id, uid: 0, task: task)
        }
    }

    /// Returns an Effect that when invoked creates a managed Task with the given ID
    /// that executes the given asynchronous throwing operation.
    ///
    /// When there is already an operation running with the same id, the existing
    /// operation will be cancelled.
    ///
    /// The `id` can be used in the transition function in order to _explicitly_ cancel
    /// the operation, if needed.
    ///
    /// A managed task will be automatically cancelled when the transducer terminates.
    ///
    /// The operation receives an environment value, that can be used to obtain
    /// dependencies or other information. It also is given the proxy - that is the receiver
    /// of any events emitted by the operation.
    ///
    /// ### Example
    ///
    /// The below example shows how to create a simple timer effect:
    ///
    ///```swift
    /// static func update(
    ///     _ state: inout State,
    ///     event: Event
    /// ) -> Effect? {
    ///     ...
    ///     case (.startTimer, .running):
    ///         return .task(id: "timer") {
    ///             while true {
    ///                 try await Task.sleep(nanoseconds: 1_000_000_000)
    ///                 try? proxy.send(.ping)
    ///             }
    ///         }
    ///```
    ///
    /// The operation above will be executed within a Swift Task which is managed
    /// by the transducer.
    ///
    /// The timer can be cancelled within the `update` function by returning a
    /// _cancellation_ effect, a static function `cancelTask(_:)`, which requires
    /// the `id` of the effect as a parameter when it has been created:
    ///```swift
    /// static func update(
    ///     _ state: inout State,
    ///     event: Event
    /// ) -> Effect? {
    ///     ...
    ///     case (.stopTimer, .running):
    ///         return .cancelTask("timer")
    ///     ...
    ///```
    /// The cancellation effect will cancel the Swift Task which executes the
    /// operation. Once the Task has been cancelled, the proxy in the above
    /// timer operation cannot send events to the transducer anymore.
    ///
    /// - Parameters:
    ///   - id: An ID that identifies this operation.
    ///   - operation: An async throwing function receiving the environment and the proxy
    ///     as parameter.
    ///   - priority: The priority of the task. Pass `nil` to use the priority from `Task.currentPriority`.
    public static func task(
        _ id: some Hashable & Sendable,
        operation: @escaping @isolated(any) @Sendable (
            Env,
            Proxy
        ) async throws -> Void,
        priority: TaskPriority? = nil
    ) -> Effect {
        Effect(id: id, operation: operation, priority: priority)
    }
    
    /// Returns an Effect that when invoked creates a managed Task that executes
    /// the given asynchronous throwing operation.
    ///
    /// When there is already an operation running with the same id, the existing
    /// operation will be cancelled.
    ///
    /// A managed task will be automatically cancelled when the transducer terminates.
    ///
    /// The operation receives an environment value, that can be used to obtain
    /// dependencies or other information. It also is given the proxy - that is the receiver
    /// of any events emitted by the operation.
    ///
    /// ### Example
    ///
    /// The below example shows how to create a simple timer effect which sends
    /// three pings and then terminates. Note, that the timer omittong an id
    /// cannot be cancelled explicitly in the update function.
    ///
    ///```swift
    /// static func update(
    ///     _ state: inout State,
    ///     event: Event
    /// ) -> Effect? {
    ///     ...
    ///     case (.startTimer, .running):
    ///         return .task() {
    ///             for _ in 0..<3  {
    ///                 try await Task.sleep(nanoseconds: 1_000_000_000)
    ///                 try? proxy.send(.ping)
    ///             }
    ///         }
    ///```
    ///
    /// The operation above will be executed within a Swift Task which is managed
    /// by the transducer.
    ///
    /// - Parameters:
    ///   - operation: An async throwing function receiving the environment and the proxy
    ///     as parameter.
    ///   - priority: The priority of the task. Pass `nil` to use the priority from `Task.currentPriority`.
    public static func task(
        operation: @escaping @isolated(any) @Sendable (
            Env,
            Proxy
        ) async throws -> Void,
        priority: TaskPriority? = nil
    ) -> Effect {
        Effect(operation: operation, priority: priority)
    }

    /// Returns an effect that when invoked executes the given closure `action(:_)`
    /// on the Transducer's isolated domain.
    ///
    /// - Parameter action: The closure to run.
    /// - Returns: A synchronous effect.
    public static func action(
        _ action: @escaping @Sendable (
            Env,
            Proxy
        ) -> Void
    ) -> Effect {
        Effect(f: { env, proxy, _, _ in
            action(env, proxy)
        })
    }
    
    /// Returns an `Effect` that when invoked, sends the given event
    /// synchronously to the transucer.
    ///
    /// - Parameter event: The event that will be sent to the transducer.
    /// - Returns: A synchronous effect.
    public static func event(_ event: Event) -> Effect {
        Effect { _, proxy, _, _ in
            try? proxy.send(event) // TODO: Check how to handle the error
        }
    }
    
    /// Returns an effect that when invoked sends the specified event after the
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

    /// Returns an effect that when invoked sends the specified event after the
    /// given duration to the transducer.
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
    
    /// Returns an effect that when invoked, cancels the operation with the
    /// given ID.
    ///
    /// - Parameters:
    ///   - id: The ID of the operation that should be cancelled.
    ///
    /// - Returns: A synchronous effect.
    public static func cancelTask(
        _ id: some Hashable & Sendable
    ) -> Effect {
        Effect { _, proxy, _, _ in
            try? proxy.cancelTask(TaskID(id))
        }
    }
    
    /// Returns an effect that when invoked cancels all operations.
    ///
    /// - Returns: A synchronous effect.
    public static func cancelAllTasks() -> Effect {
        Effect { _, proxy, _, _ in
            try? proxy.cancelAllTasks()
        }
    }
    
    
    // TODO: fix when available: "Noncopyable type 'Effect<Event, Env>' cannot be used within a variadic type yet."
    /// Creates an effect which when invoked invokes all the effects passed as
    /// arguments.
    public static func effects(_ effects: Effect...) -> Effect {
        Self.effects(effects)
    }
    
    /// Creates an effect which when invoked invokes all the effects passed as
    /// parameters.
    public static func effects(_ effects: [Effect]) -> Effect {
        Effect { env, proxy, context, isolated in
            effects.forEach { effect in
                effect.f(env, proxy, context, isolated)
            }
        }
    }
    
    // This function does exists solely to define the isolation where
    // `context` can be mutated.
    static func removeCompletedTask(
        id: some Hashable & Sendable,
        uid: Context.UID,
        context: Context,
        isolated: isolated (any Actor) = #isolation
    ) {
        context.removeCompleted(id: id, uid: uid)
    }

}


struct OakTask {
    init(
        id: some Hashable & Sendable,
        task: Task<Void, Error>
    ) {
        self.id = TaskID(id)
        self.task = task
    }
    
    init(task: Task<Void, Error>) {
        self.id = nil
        self.task = task
    }
    
    let id: TaskID?
    var task: Task<Void, Error>
}


