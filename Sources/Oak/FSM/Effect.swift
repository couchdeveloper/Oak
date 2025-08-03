/// Represents a side effect that may interact with the environment.
///
/// The `Effect` struct encapsulates an asynchronous operation that will be executed by the transducer.
/// The operation may interact with the environment, send events, or perform other actions as part of a state
/// machine's transition logic. The operation obtains a value `Env` as an input parameter which can be
/// useds to provide dependencies and configuration values from the environment.
///
///
/// # Usage
/// Effects will be created within a transducer's `update` method and returned to be executed
/// by the state machine runtime.
///
/// - Parameters:
///   - Env: The environment type, which may be isolated or `Sendable`.
///   - Event: The event type that the effect may send back to the state machine.
public struct Effect<T: EffectTransducer> {
    public typealias Input = T.Input
    public typealias Event = T.Event
    public typealias Env = T.Env

    private let f: (Env, Input, Context, isolated any Actor) async throws -> [Event]

    /// Initialises the effect.
    /// - Parameter f: An async throwing function, that might cause side effects.
    ///
    /// For best performance, in very demanding scenarios, the given function should avoid to close over
    /// state. That is, the closure should not capture values.
    internal init(
        f: @escaping (Env, Input, Context, isolated any Actor) async throws -> [Event],
    ) {
        self.f = f
    }

    internal func invoke(
        env: Env,
        input: Input,
        context: Context,
        systemActor: isolated any Actor = #isolation
    ) async throws -> [Event] {
        try await self.f(env, input, context, systemActor)
    }

    /// Executes the closure `action` on the specified global actor provided by
    /// the caller.
    ///
    /// The action may return events provided in an array which gets processed
    /// by the system. These events will be procesed _synchronously_ and in
    /// order. The next processed event is alway the first event in the array
    /// from the current action.
    ///
    /// Processing of the events send via the Input will be suspendend until after
    /// all events returned from actions have been processed.
    ///
    /// > Tip: For best performance, the action should avoid to close over state. That is,
    /// the closure should not capture values. Instead, you might want to access values
    /// provided in the `env` parameter.
    ///
    /// > Caution: An event returned from an action will allways be processed
    ///   in the update function, regardless whether the state became terminal.
    ///   The logic needs to account for this case.
    ///
    /// The global actor usually matches the global actor where the environment `Env`
    /// is isolated on, so that `action` can access the environment on the specified
    /// global actor.
    ///
    /// `action(_:_:)` is an async throwing function. The processing of events will be
    /// suspended until the action function returns. Throwing an error will terminate
    /// the transducer and causing the`run` function to throw this error.
    ///
    /// Accesses to the environment parameter is safe if `Env` conforms to
    /// `Sendable` or if `Env` is isolated to the same global actor.
    ///
    /// > Note:
    ///   The use of `@isolated(any)` in the parameter list ensures that the closure
    ///   is executed with the specified actor isolation, which is important for thread safety
    ///   when accessing actor-isolated environments (`Env`).
    ///
    /// ## Example:
    /// Given an Environment `Env` isolated to global actor `@MainActor`:
    /// ```swift
    /// @MainActor class Env { ... }
    /// ```
    /// An Action Effect, created in the `updated` function of the transducer, can safely
    /// access the environment value when specifiying the same global actor for the action
    /// closure:
    /// ```swift
    /// let effect = T.Effect(action: { @MainActor env in
    ///     let delegate = env.createDelegate()
    ///     return [.delegate(delegate)]
    /// })
    /// ```
    public init(
        action: @Sendable @escaping @isolated(any) (
            Env,
        ) async throws -> sending [Event]
    ) where Env: Sendable {
        self.f = { env, input, context, systemActor in
            try await action(env)
        }
    }

    /// Executes the closure `action` on the specified global actor provided by
    /// the caller.
    ///
    /// The action returns an event that will be _synchronously_ processed by the
    /// transducer.
    ///
    /// Processing of the events send via the Input will be suspendend until after
    /// all events returned from actions have been processed.
    ///
    /// > Tip: For best performance, the action should avoid to close over state. That is,
    /// the closure should not capture values. Instead, you might want to access values
    /// provided in the `env` parameter.
    ///
    /// > Caution: An event returned from an action will allways be processed
    ///   in the update function, regardless whether the state became terminal.
    ///   The logic needs to account for this case.
    ///
    /// The global actor usually matches the global actor where the environment `Env`
    /// is isolated on, so that `action` can access the environment on the specified
    /// global actor.
    ///
    /// `action(_:_:)` is an async throwing function. The processing of events will be
    /// suspended until the action function returns. Throwing an error will terminate
    /// the transducer and causing the`run` function to throw this error.
    ///
    /// Accesses to the environment parameter is safe if `Env` conforms to
    /// `Sendable` or if `Env` is isolated to the same global actor.
    ///
    /// > Note:
    ///   The use of `@isolated(any)` in the parameter list ensures that the closure
    ///   is executed with the specified actor isolation, which is important for thread safety
    ///   when accessing actor-isolated environments (`Env`).
    ///
    /// ## Example:
    /// Given an Environment `Env` isolated to global actor `@MainActor`:
    /// ```swift
    /// @MainActor class Env { ... }
    /// ```
    /// An Action Effect, created in the `updated` function of the transducer, can safely
    /// access the environment value when specifiying the same global actor for the action
    /// closure:
    /// ```swift
    /// let effect = T.Effect(action: { @MainActor env in
    ///     let delegate = env.createDelegate()
    ///     return .delegate(delegate)
    /// })
    /// ```
    public init(
        action: @Sendable @escaping @isolated(any) (
            Env,
        ) async throws -> sending Event
    ) where Env: Sendable {
        self.f = { env, input, context, systemActor in
            let event = try await action(env)
            return [event]
        }
    }

    /// Executes the closure `action` on the "systemActor", i.e. the actor specified where
    /// the function `run` is executing.
    ///
    /// The action may return events provided in an array which gets processed
    /// by the system. These events will be procesed _synchronously_ and in
    /// order. The next processed event is alway the first event in the array
    /// from the current action.
    ///
    /// Processing of the events send via the Input will be suspendend until after
    /// all events returned from actions have been processed.
    ///
    /// > Tip: For best performance, the action should avoid to close over state. That is,
    /// the closure should not capture values. Instead, you might want to access values
    /// provided in the `env` parameter.
    ///
    /// > Caution: An event returned from an action will allways be processed
    ///   in the update function, regardless whether the state became terminal.
    ///   The logic needs to account for this case.
    ///
    /// The closure is always executed on the system actor, regardless of any global actor
    /// isolation on `Env`.
    ///
    /// - Parameter action: An async throwing function that performs the actual work. It
    /// can be used to send events back to the transducer, invoke side effects or access the
    /// environment value. The closure receives
    ///     - the environment (`Env`) containing any required dependencies and configuration data,
    ///     - the input (`Input`) for sending events to the transducer, and
    ///     - an isolated actor reference for thread-safe operations.
    ///
    /// When the action function throws an error, it will terminate the transducer and causing
    /// the`run` function to rethrow it.
    public init(
        isolatedAction action: @Sendable @escaping (
            Env,
            isolated any Actor
        ) async throws -> sending [Event]
    ) {
        self.f = { env, input, context, systemActor in
            try await action(env, systemActor)
        }
    }

    /// Executes the closure `action` on the "systemActor", i.e. the actor specified where
    /// the function `run` is executing.
    ///
    /// The action returns an event that will be _synchronously_ processed by the
    /// transducer.
    ///
    /// Processing of the events send via the Input will be suspendend until after
    /// all events returned from actions have been processed.
    ///
    /// > Tip: For best performance, the action should avoid to close over state. That is,
    /// the closure should not capture values. Instead, you might want to access values
    /// provided in the `env` parameter.
    ///
    /// > Caution: An event returned from an action will allways be processed
    ///   in the update function, regardless whether the state became terminal.
    ///   The logic needs to account for this case.
    ///
    /// The closure is always executed on the system actor, regardless of any global actor
    /// isolation on `Env`.
    ///
    /// - Parameter action: An async throwing function that performs the actual work. It
    /// can be used to send events back to the transducer, invoke side effects or access the
    /// environment value. The closure receives
    ///     - the environment (`Env`) containing any required dependencies and configuration data,
    ///     - the input (`Input`) for sending events to the transducer, and
    ///     - an isolated actor reference for thread-safe operations.
    ///
    /// When the action function throws an error, it will terminate the transducer and causing
    /// the`run` function to rethrow it.
    public init(
        isolatedAction action: @Sendable @escaping (
            Env,
            isolated any Actor
        ) async throws -> sending Event
    ) {
        self.f = { env, input, context, systemActor in
            let event = try await action(env, systemActor)
            return [event]
        }
    }

    /// Creates an effect that executes an asynchronous operation executing within an
    /// unstructured Task managed by the transducer.
    ///
    /// An operation can send events back to the transducer using the provided `input`
    /// parameter. Note, that the input parameter may be shared with other components
    /// which may also send events concurrently. The events will be processed in order,
    /// as they arrive in the event buffer.
    ///
    /// The closure is always executed on the "systemActor", i.e. the actor specified where the
    /// function `run` is executing, regardless of any global actor isolation on `Env`.
    ///
    /// - Parameters:
    ///   - id: An optional identifier for the effect. If not provided, a system-generated identifier will be
    ///   used.
    ///   - operation: An asynchronous closure that performs the actual work. The closure receives
    ///     - the environment (`Env`) containing any required dependencies and configuration data,
    ///     - the input (`Input`) for sending events to the transducer, and
    ///     - an isolated actor reference for thread-safe operations.
    ///
    /// The transducer offers lifecycle management for the Swift Task which executes the operation.
    /// The given `id` can be used to explicitly cancel the operation from within the transducer's
    /// `update` function. When the transducer terminates, and the operation is still executing, its
    /// Task will be cancelled automatically.
    ///
    /// - Note: If the operation throws an error:
    ///   - If it's a `CancellationError`, the transducer continues normally.
    ///   - For any other error, it will terminate the transducer and causing
    ///     the`run` function to rethrow it.
    ///
    public init(
        id: (some Hashable & Sendable)? = Optional<ID>.none,
        isolatedOperation operation: @Sendable @escaping (
            Env,
            Input,
            isolated any Actor
        ) async throws -> Void
    ) {
        self.f = { env, input, context, systemActor in
            let id = id == nil ? context.id() : ID(id!)
            let uid = context.uid()
            // The `task` manages the lifecycle of the asynchronous operation.
            let task = Task {
                // Caution: parameter `systemActor` MUST be *imported* into the
                // Task's closure. Importing `systemActor` ensures that the Task
                // executes with the correct actor isolation, which is critical for
                // thread safety and for safely accessing any actor-isolated resources
                // (such as the environment or context) within the Task.
                do {
                    try await operation(env, input, systemActor)
                } catch is CancellationError {
                    // task has been cancelled by the system, proceed normally.
                } catch {
                    // When an operation fails, it terminates the transducer
                    // with the error:
                    context.terminate(error)
                }
                context.removeCompleted(uid: uid, id: id, isolated: systemActor)
            }
            context.register(task: task, uid: uid, id: id)
            return []
        }
    }

    // Note: we do have to explicitly add `Sendable` conformance to `Env` to
    // ensure `Env` is sendbale in uses in the `@Sendable` closure. The compiler
    // would successfully compile it even without being constraint to be
    // `Sendable`, which is incorrect.
    //
    // When `Env` is not Sendable, but isolated to a gloabal actor and operation
    // is specified to be called on the *same* global actor, it compiles
    // successfully, which is correct. Otherwiswe if operation is using another
    // global actor it fails to compile, which is also correct.
    //
    // When `Env` is not Sendable and not isolated to a global actor it should
    // not compile successfully, no matter which global actor (or none) is
    // specified for operation. In cases where operation is specifiedy with the
    // systemActor (which needs to be a global actor) then it will also not
    // compile, even it would be safe. The fix is to call the other overload
    // above where the closure `operation` is isolated to the systemActor.

    // unsafe concurrent accesses to parameter `env` within multiple calls to
    // operation (which may have different isolations) and also between systemActor,
    // EXCEPT where all calls to operation are isolated to `systemActor`.

    /// Creates an effect that executes an asynchronous operation executing within an
    /// unstructured Task managed by the transducer.
    ///
    /// An operation can send events back to the transducer using the provided `input`
    /// parameter. Note, that the input parameter may be shared with other components
    /// which may also send events concurrently. The events will be processed in order,
    /// as they arrive in the event buffer.
    ///
    /// The operation is executed on the provided global actor associated to the closure. Usually, this is
    /// the global actor where `Env` is isolated to, so that accessing it is safe from within the operation.
    ///
    /// - Parameters:
    ///   - id: An optional identifier for the effect. If not provided, a system-generated identifier will be
    ///   used.
    ///   - operation: An asynchronous closure that performs the actual work. The closure receives
    ///     - the environment (`Env`) containing any required dependencies and configuration data,
    ///     - the input (`Input`) for sending events to the transducer
    ///
    /// The transducer offers lifecycle management for the Swift Task which executes the operation.
    /// The given `id`, if not `nil` can be used to explicitly cancel the operation from within the
    /// transducer's `update` function. When the transducer terminates, and the operation is still
    /// executing, its Task will be cancelled automatically.
    ///
    /// - Note: If the operation throws an error:
    ///   - If it's a `CancellationError`, the transducer continues normally.
    ///   - For any other error, it will terminate the transducer and causing
    ///     the`run` function to rethrow it.
    ///
    public init(
        id: (some Hashable & Sendable)? = Optional<ID>.none,
        operation: @Sendable @escaping @isolated(any) (
            Env,
            Input
        ) async throws -> Void
    ) where Env: Sendable {
        self.f = { env, input, context, systemActor in
            let id = id == nil ? context.id() : ID(id!)
            let uid = context.uid()
            // The `task` manages the lifecycle of the asynchronous operation.
            let task = Task {
                // Caution: parameter `systemActor` MUST be *imported* into the
                // Task's closure. Importing `systemActor` ensures that the Task
                // executes with the correct actor isolation, which is critical for
                // thread safety and for safely accessing any actor-isolated resources
                // (such as the environment or context) within the Task.
                do {
                    try await operation(env, input)
                } catch is CancellationError {
                    // task has been cancelled by the system, proceed normally.
                } catch {
                    // When an operation fails, it terminates the transducer
                    // with the error:
                    context.terminate(error)
                }
                context.removeCompleted(uid: uid, id: id, isolated: systemActor)
            }
            context.register(task: task, uid: uid, id: id)
            return []
        }
    }

}

extension Effect {

    /// Creates an effect that executes an asynchronous operation after a specified duration.
    ///
    /// This effect will wait for the specified duration before executing the provided operation.
    /// If the operation completes successfully, the effect will complete with its result.
    /// If the operation fails with an error, the effect will propagate that error to the caller,
    /// causing the transducer's run function to return with this error.
    ///
    /// - Parameters:
    ///   - id: An optional unique identifier for this effect. When provided, it can be used for
    ///     cancellation, or to distinguish between multiple effects of the same type.
    ///   - operation: The asynchronous operation to execute after the duration has elapsed.
    ///   - duration: The time interval to wait before executing the operation.
    ///   - tolerance: An optional tolerance for the duration, which allows the system to adjust
    ///     the timing of the operation slightly if needed.
    ///   - clock: The clock to use for measuring the duration. Defaults to `ContinuousClock()`.
    ///
    /// This effect will execute the operation on the "systemActor", i.e. the actor
    /// specified where the function `run` is executing, regardless of any global actor i
    /// solation on `Env`.
    ///
    /// - Note: If the operation throws an error:
    ///   - If it's a `CancellationError`, the transducer continues normally.
    ///   - For any other error, it will terminate the transducer and causing
    ///     the`run` function to rethrow it.
    ///
    /// - Important: The transducer offers lifecycle management for the Swift Task which
    /// executes the operation.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    public init<C: Clock>(
        id: (some Hashable & Sendable)? = Optional<ID>.none,
        isolatedOperation operation: @Sendable @escaping (
            Env,
            Input,
            isolated any Actor
        ) async throws -> Void,
        after duration: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = ContinuousClock(),
    ) {
        self.f = { env, input, context, systemActor in
            let id = id == nil ? context.id() : ID(id!)
            let uid = context.uid()
            let task = Task {
                // Caution: parameter `systemActor` MUST be *imported* into the
                // Task's closure - which is required for the task to
                // take this isolation.
                do {
                    try await Task.sleep(for: duration, tolerance: tolerance, clock: clock)
                    try await operation(env, input, systemActor)
                } catch is CancellationError {
                    // task has been cancelled by the system, proceed normally.
                } catch {
                    // When an operation fails, it terminates the transducer
                    // with the error:
                    context.terminate(error)
                }
                context.removeCompleted(uid: uid, id: id, isolated: systemActor)
            }
            context.register(task: task, uid: uid, id: id)
            return []
        }
    }

    /// Creates an effect that executes an asynchronous operation after a specified duration.
    ///
    /// This effect will wait for the specified duration before executing the provided operation.
    /// If the operation completes successfully, the effect will complete with its result.
    /// If the operation fails with an error, the effect will propagate that error to the caller,
    /// causing the transducer's run function to return with this error.
    ///
    /// - Parameters:
    ///   - id: An optional unique identifier for this effect. When provided, it can be used for
    ///     cancellation, or to distinguish between multiple effects of the same type.
    ///   - operation: The asynchronous operation to execute after the duration has elapsed.
    ///   - duration: The time interval to wait before executing the operation.
    ///   - tolerance: An optional tolerance for the duration, which allows the system to adjust
    ///     the timing of the operation slightly if needed.
    ///   - clock: The clock to use for measuring the duration. Defaults to `ContinuousClock()`.
    ///
    /// This effect will execute the operation on the global actor associated to the closure.
    /// This enables to match the global actor where `Env` is isolated to, so that accessing
    /// it is safe.
    ///
    /// - Note: If the operation throws an error:
    ///   - If it's a `CancellationError`, the transducer continues normally.
    ///   - For any other error, it will terminate the transducer and causing
    ///     the`run` function to rethrow it.
    ///
    /// - Important: The transducer offers lifecycle management for the Swift Task which
    /// executes the operation.
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    public init<C: Clock>(
        id: (some Hashable & Sendable)? = Optional<ID>.none,
        operation: @Sendable @escaping @isolated(any) (
            Env,
            Input
        ) async throws -> Void,
        after duration: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = ContinuousClock(),
    ) {
        self.f = { env, input, context, systemActor in
            let id = id == nil ? context.id() : ID(id!)
            let uid = context.uid()
            let task = Task {
                // Caution: parameter `systemActor` MUST be *imported* into the
                // Task's closure - which is required for the task to
                // take this isolation.
                do {
                    try await Task.sleep(for: duration, tolerance: tolerance, clock: clock)
                    try await operation(env, input)
                } catch is CancellationError {
                    // task has been cancelled by the system, proceed normally.
                } catch {
                    // When an operation fails, it terminates the transducer
                    // with the error:
                    context.terminate(error)
                }
                context.removeCompleted(uid: uid, id: id, isolated: systemActor)
            }
            context.register(task: task, uid: uid, id: id)
            return []
        }
    }

}

extension Effect {

    /// Creates an effect which, when invoked, sends an event to the transducer.
    ///
    /// The event will be directly executed and has precedence over any other events
    /// enqueued in the event buffer.
    ///
    /// - Parameter event: The event which will be sent.
    /// - Returns: An effect.
    public static func event(_ event: sending Event) -> Effect {
        Effect(f: { env, input, context, isolated in
            isolated.assertIsolated()
            nonisolated(unsafe) let event = event
            return [event]
        })
    }

}

#if false
// Pattern that the region based isolation checker does not understand how to check. Please file a bug
public func action<T: Transducer>(
    type: T.Type,
    action: sending @escaping (
        sending T.Env,
        T.Input,
        isolated (any Actor)?
    ) -> Void,
    // isolated: isolated (any Actor)? = #isolation
) -> T.Effect {
    // let boxedAction = UnsafeIsolatedBox2(action)
    return T.Effect.init({ env, input, _, isolated in  // Pattern that the region based isolation checker does not understand how to check. Please file a bug
        // boxedAction.open()(env, input, isolated)
    })
}
#endif

#if false
extension Effect {

    // MARK: - Public

    public static func action(
        _ action: sending @escaping (
            sending Env,
            Input,
            isolated (any Actor)?
        ) -> Void,
        // isolated: isolated (any Actor)? = #isolation
    ) -> Self {
        // let boxedAction = UnsafeIsolatedBox2(action)
        return Effect({ env, input, _, isolated in  // Pattern that the region based isolation checker does not understand how to check. Please file a bug
            // boxedAction.open()(env, input, isolated)
        })
    }

}
#endif

#if false
extension Effect {

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    public static func event<C: Clock>(
        _ event: sending Event,
        id: some Hashable & Sendable,
        after duration: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = ContinuousClock(),
        isolated: isolated (any Actor)? = #isolation
    ) -> Self {
        let boxedEvent = UnsafeIsolatedBox(event)
        return Self.init({ env, proxy, context, currentActor in
            let uid = context.uid()
            let task = Task.init {
                do {
                    try await Task.sleep(for: duration, tolerance: tolerance, clock: clock)
                    try proxy.send(boxedEvent.open(isolated))
                } catch {
                    // TODO: handle error
                }
                context.removeCompleted(uid: uid, id: ID(id), isolated: isolated)
            }
            context.register(task: task, uid: uid, id: ID(id), isolated: currentActor)
        })
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    public static func event<C: Clock>(
        _ event: sending Event,
        after duration: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = ContinuousClock(),
        // isolated: isolated (any Actor)? = #isolation
    ) -> Self {
        let boxedEvent = UnsafeIsolatedBox(event)
        return Self.init({ env, proxy, context, currentActor in
            let id = context.id()
            let uid = context.uid()
            let task = Task.init {
                do {
                    try await Task.sleep(for: duration, tolerance: tolerance, clock: clock)
                    try proxy.send(boxedEvent.open(currentActor))
                } catch {
                    // TODO: handle error
                }
                context.removeCompleted(uid: uid, id: id, isolated: currentActor)
            }
            context.register(task: task, uid: uid, id: id, isolated: currentActor)
        })
    }

}
#endif

extension Effect {

    /// Combines multiple effects into a single effect that executes them sequentially.
    /// - Parameters:
    ///   - effect1: The first effect to combine.
    ///   - effect2: The second effect to combine.
    ///
    /// This method allows you to combine multiple effects into a single effect that executes them in order.
    /// Each effect will be executed one after the other, and if any effect throws an error,
    /// the combined effect will also throw that error, terminating the transducer.
    public static func combine(
        _ effect1: consuming sending Self,
        _ effect2: consuming sending Self,
    ) -> Effect {
        let f1 = effect1.f
        let f2 = effect2.f
        return Self(f: { env, proxy, context, isolated in
            let events1 = try await f1(env, proxy, context, isolated)
            let events2 = try await f2(env, proxy, context, isolated)
            return events1 + events2

        })
    }

    /// Combines multiple effects into a single effect that executes them sequentially.
    /// - Parameters:
    ///   - effect1: The first effect to combine.
    ///   - effect2: The second effect to combine.
    ///   - effect3: The third effect to combine.
    ///
    /// This method allows you to combine multiple effects into a single effect that executes them in order.
    /// Each effect will be executed one after the other, and if any effect throws an error,
    /// the combined effect will also throw that error, terminating the transducer.
    public static func combine(
        _ effect1: consuming sending Self,
        _ effect2: consuming sending Self,
        _ effect3: consuming sending Self,
    ) -> Effect {
        let f1 = effect1.f
        let f2 = effect2.f
        let f3 = effect3.f
        return Self(f: { env, proxy, context, isolated in
            let events1 = try await f1(env, proxy, context, isolated)
            let events2 = try await f2(env, proxy, context, isolated)
            let events3 = try await f3(env, proxy, context, isolated)
            return events1 + events2 + events3
        })
    }

    /// Combines multiple effects into a single effect that executes them sequentially.
    /// - Parameters:
    ///   - effect1: The first effect to combine.
    ///   - effect2: The second effect to combine.
    ///   - effect3: The third effect to combine.
    ///   - effect4: The fourth effect to combine.
    ///
    /// This method allows you to combine multiple effects into a single effect that executes them in order.
    /// Each effect will be executed one after the other, and if any effect throws an error,
    /// the combined effect will also throw that error, terminating the transducer.
    public static func combine(
        _ effect1: consuming sending Self,
        _ effect2: consuming sending Self,
        _ effect3: consuming sending Self,
        _ effect4: consuming sending Self,
    ) -> Effect {
        let f1 = effect1.f
        let f2 = effect2.f
        let f3 = effect3.f
        let f4 = effect4.f
        return Self(f: { env, proxy, context, isolated in
            let events1 = try await f1(env, proxy, context, isolated)
            let events2 = try await f2(env, proxy, context, isolated)
            let events3 = try await f3(env, proxy, context, isolated)
            let events4 = try await f4(env, proxy, context, isolated)
            return events1 + events2 + events3 + events4
        })
    }

    /// Combines multiple effects into a single effect that executes them sequentially.
    /// - Parameters:
    ///   - effect1: The first effect to combine.
    ///   - effect2: The second effect to combine.
    ///   - effect3: The third effect to combine.
    ///   - effect4: The fourth effect to combine.
    ///   - effect5: The fifth effect to combine.
    ///
    /// This method allows you to combine multiple effects into a single effect that executes them in order.
    /// Each effect will be executed one after the other, and if any effect throws an error,
    /// the combined effect will also throw that error, terminating the transducer.
    public static func combine(
        _ effect1: consuming sending Self,
        _ effect2: consuming sending Self,
        _ effect3: consuming sending Self,
        _ effect4: consuming sending Self,
        _ effect5: consuming sending Self
    ) -> Effect {
        let f1 = effect1.f
        let f2 = effect2.f
        let f3 = effect3.f
        let f4 = effect4.f
        let f5 = effect5.f
        return Self(f: { env, proxy, context, isolated in
            let events1 = try await f1(env, proxy, context, isolated)
            let events2 = try await f2(env, proxy, context, isolated)
            let events3 = try await f3(env, proxy, context, isolated)
            let events4 = try await f4(env, proxy, context, isolated)
            let events5 = try await f5(env, proxy, context, isolated)
            return events1 + events2 + events3 + events4 + events5
        })
    }

    // TODO: Enable this code when the issue has been fixed in the compiler.
    // public static func effects(
    //     _ effects: sending Effect...  // Error: 'sending' may only be used on parameters and results
    // ) -> Self {
    //     return Self(f: { env, proxy, context, isolated in
    //         for effect in effects {
    //             try await effect.f(env, proxy, context, isolated)
    //         }
    //     })
    // }

}

extension Effect {

    /// Cancels the task with the specified identifier.
    ///
    /// - Parameter id: The identifier of the task to cancel.
    /// - Returns: An effect that cancels the task.
    ///
    /// Create this effect and return it in the `update` function
    /// to cancel a previously created effect.
    ///
    public static func cancelTask(_ id: some Hashable & Sendable) -> Effect {
        return Effect(f: { env, input, context, isolated in
            context.cancelTask(id: ID(id), isolated: isolated)
            return []
        })
    }
}
