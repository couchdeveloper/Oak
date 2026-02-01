/// **Effect - Asynchronous Side Effect Management**
///
/// Encapsulates side effects that interact with the environment during state transitions.
/// Effects execute asynchronously and can send events back to the transducer.
///
/// Oak provides two fundamental effect types with distinct execution models:
///
/// ## Action Effects - Structured Concurrency
/// Execute synchronously during the computation cycle with immediate event
/// processing. Events are processed before any Input buffer events, with state
/// guarantees maintained.
///
/// **Choose when:** Need immediate processing, state consistency is critical, or
/// work is CPU-bound and fast.
///
/// ## Operation Effects - Unstructured Tasks
/// Execute as managed Tasks concurrently with the transducer.
/// Events are sent asynchronously via Input and support cancellation.
///
/// **Choose when:** Need async work, I/O operations, cancellation support, or
/// long-running tasks.
///
/// ## Quick Decision Guide
/// - **Immediate processing + state guarantees** → Action Effects
/// - **Async work + cancellation** → Operation Effects
/// - **Single event immediately** → `.event()` static method
/// - **Cancel running work** → `.cancelTask()` with Operation Effects
///
/// ## Example Usage
/// ```swift
/// // Action Effect - synchronous environment import
/// Effect(isolatedAction: { env, isolated in
///     return .configureContext(env.createContext())
/// })
///
/// // Operation Effect - async network request
/// Effect(id: "load", isolatedOperation: { env, input, isolated in
///     let data = try await env.service.load()
///     try input.send(.dataLoaded(data))
/// })
/// ```
///
public struct Effect<T: EffectTransducer> {
    public typealias Input = T.Input
    public typealias Event = T.Event
    public typealias Env = T.Env
    
    private let f: (Env, Input, Context, isolated any Actor) async throws -> [Event]
    
    /// **Internal Effect Constructor**
    ///
    /// Low-level initializer for creating custom effects. Used internally by
    /// public initializers. External users should prefer the specific `action` or
    /// `operation` initializers.
    ///
    /// - Parameter f: Async function that implements the effect behavior and
    ///   returns events.
    ///
    /// > Tip: For best performance, avoid capturing values in the closure.
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
    
}

// MARK: - Initializers

extension Effect {

    /// **Action Effect — Global Actor (Multiple Events)**
    ///
    /// Runs the action on a caller-specified global actor. Events returned from the action
    /// are delivered synchronously during the current computation cycle, before any buffered
    /// `Input` events.
    ///
    /// Use this when you need immediate, in-order processing on a particular global actor,
    /// or when `Env` is isolated to that actor.
    ///
    /// - Parameter action: Async closure that receives the environment on the specified
    ///   global actor. Return zero or more events to be processed immediately.
    ///
    /// > Tip: Minimize captures in the closure for best performance.
    ///
    /// > Caution: Because events are handled synchronously, reaching a terminal state halts
    ///  further processing in this cycle.
    ///
    /// ## Related Methods
    /// - ``init(action:)-((Env)->Event)`` – Global actor isolation (single event)
    /// - ``init(isolatedAction:)-((Env,Actor)->[Event])`` – System actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->Event)`` – System actor isolation (single event)
    /// - ``init(id:operation:)`` – Async unstructured task on a global actor
    /// - ``init(id:operation:after:tolerance:clock:)``  – Async unstructured task on a global actor
    /// - ``init(id:isolatedOperation:)`` – System actor isolation
    /// - ``init(id:isolatedOperation:after:tolerance:clock:)`` – System actor isolation
    public init(
        action: @Sendable @escaping @isolated(any) (
            Env
        ) async throws -> sending [Event]
    ) where Env: Sendable {
        self.f = { env, input, context, systemActor in
            try await action(env)
        }
    }

    /// **Action Effect — Global Actor (Single Event)**
    ///
    /// Runs the action on a caller-specified global actor and returns a single event.
    /// The event is delivered synchronously during the current computation cycle, before
    /// any buffered `Input` events.
    ///
    /// Use this when you need immediate processing on a particular global actor,
    /// or when `Env` is isolated to that actor.
    ///
    /// - Parameter action: Async closure that receives the environment on the specified
    ///   global actor. Return a single event to be processed immediately.
    ///
    /// > Tip: Minimize captures in the closure for best performance.
    ///
    /// > Caution: Because events are handled synchronously, reaching a terminal state halts
    /// further processing in this cycle.
    ///
    /// ## Related Methods
    /// - ``init(action:)-((Env)->[Event])`` – Global actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->[Event])`` – System actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->Event)`` – System actor isolation (single event)
    /// - ``init(id:operation:)`` – Async unstructured task on a global actor
    /// - ``init(id:operation:after:tolerance:clock:)``  – Async unstructured task on a global actor
    /// - ``init(id:isolatedOperation:)`` – System actor isolation
    /// - ``init(id:isolatedOperation:after:tolerance:clock:)`` – System actor isolation
    public init(
        action: @Sendable @escaping @isolated(any) (
            Env
        ) async throws -> sending Event
    ) where Env: Sendable {
        self.f = { env, input, context, systemActor in
            let event = try await action(env)
            return [event]
        }
    }

    /// **Action Effect — System Actor (Multiple Events)**
    ///
    /// Runs the action on the same actor as the transducer's run loop (the “system actor”),
    /// independent of any global-actor isolation on `Env`. Events returned from the action
    /// are delivered synchronously during the current computation cycle, before any buffered
    /// `Input` events.
    ///
    /// Use this when you need immediate, in-order processing with the same isolation as the
    /// transducer, or when `Env` is only safe to access from the system actor.
    ///
    /// - Parameter action: Async closure that receives the environment and an isolated
    ///   reference to the system actor. Return zero or more events to be processed immediately.
    ///
    /// > Tip: Minimize captures in the closure for best performance.
    ///
    /// > Caution: Because events are handled synchronously, reaching a terminal state halts
    ///  further processing in this cycle.
    ///
    /// ## Related Methods
    /// - ``init(action:)-((Env)->Event)`` – Global actor isolation (single event)
    /// - ``init(action:)-((Env)->[Event])`` – Global actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->Event)`` – System actor isolation (single event)
    /// - ``init(id:operation:)`` – Async unstructured task on a global actor
    /// - ``init(id:operation:after:tolerance:clock:)``  – Async unstructured task on a global actor
    /// - ``init(id:isolatedOperation:)`` – System actor isolation
    /// - ``init(id:isolatedOperation:after:tolerance:clock:)`` – System actor isolation
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

    /// **Action Effect — System Actor (Single Event)**
    ///
    /// Runs the action on the transducer's system actor and returns a single event.
    /// The event is delivered synchronously during the current computation cycle,
    /// before any buffered `Input` events, regardless of any global-actor isolation on `Env`.
    ///
    /// Use this when you need immediate event processing with the same isolation as the
    /// transducer, or when `Env` is only safe to access from the system actor.
    ///
    /// - Parameter action: Async closure that receives the environment and an isolated
    ///   reference to the system actor. Return a single event to be processed immediately.
    ///
    /// > Tip: Minimize captures in the closure for best performance.
    ///
    /// > Caution: Because events are handled synchronously, reaching a terminal state halts
    /// further processing in this cycle.
    ///
    /// ## Related Methods
    /// - ``init(action:)-((Env)->Event)`` – Global actor isolation (single event)
    /// - ``init(action:)-((Env)->[Event])`` – Global actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->[Event])`` – System actor isolation (multiple events)
    /// - ``init(id:operation:)`` – Async unstructured task on a global actor
    /// - ``init(id:operation:after:tolerance:clock:)``  – Async unstructured task on a global actor
    /// - ``init(id:isolatedOperation:)`` – System actor isolation
    /// - ``init(id:isolatedOperation:after:tolerance:clock:)`` – System actor isolation
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

    /// **Operation Effect — System Actor Task (Immediate)**
    ///
    /// Runs the operation as a managed Task on the transducer's system actor. Any events must
    /// be sent asynchronously via `Input` and are processed alongside other concurrent events.
    ///
    /// Use this when you need concurrent work with system-actor isolation (for example, to
    /// safely access system-actor–isolated resources) and explicit cancellation support.
    ///
    /// - Parameters:
    ///   - id: Optional identifier used to cancel the task. Auto-generated if `nil`.
    ///   - operation: Async closure that receives the environment, the input proxy, and an
    ///     isolated reference to the system actor.
    ///
    /// > Tip: Import the system actor into the Task closure to preserve isolation.
    ///
    /// > Note: `CancellationError` is ignored; other errors terminate the transducer.
    ///
    /// ## Related Methods
    /// - ``init(action:)-((Env)->Event)`` – Global actor isolation (single event)
    /// - ``init(action:)-((Env)->[Event])`` – Global actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->[Event])`` – System actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->Event)`` – System actor isolation (single event)
    /// - ``init(id:operation:)`` – Async unstructured task on a global actor
    /// - ``init(id:operation:after:tolerance:clock:)``  – Async unstructured task on a global actor
    /// - ``init(id:isolatedOperation:after:tolerance:clock:)`` – System actor isolation
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
                // Caution: parameter `systemActor` MUST be *captured* in the
                // Task's closure. Capturing `systemActor` ensures that the Task
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

    /// **Operation Effect — Global Actor Task (Immediate)**
    ///
    /// Runs the operation as a managed Task on a caller-specified global actor. Any events must
    /// be sent asynchronously via `Input` and are processed alongside other concurrent events.
    ///
    /// Use this when you need concurrent work on a specific global actor that matches your
    /// environment's isolation, with explicit cancellation support.
    ///
    /// - Parameters:
    ///   - id: Optional identifier used to cancel the task. Auto-generated if `nil`.
    ///   - operation: Async closure that receives the environment and the input proxy on the
    ///     specified global actor.
    ///
    /// > Note: `CancellationError` is ignored; other errors terminate the transducer.
    ///
    /// ## Related Methods
    /// - ``init(action:)-((Env)->Event)`` – Global actor isolation (single event)
    /// - ``init(action:)-((Env)->[Event])`` – Global actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->[Event])`` – System actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->Event)`` – System actor isolation (single event)
    /// - ``init(id:operation:after:tolerance:clock:)``  – Async unstructured task on a global actor
    /// - ``init(id:isolatedOperation:)`` – System actor isolation
    /// - ``init(id:isolatedOperation:after:tolerance:clock:)`` – System actor isolation
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
                // Caution: parameter `systemActor` MUST be *captured* in the
                // Task's closure. Capturing `systemActor` ensures that the Task
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

    /// **Operation Effect — System Actor Task (Delayed)**
    ///
    /// Schedules the operation to run as a managed Task on the transducer's system actor
    /// after a specified delay. Any events must be sent asynchronously via `Input` and are
    /// processed alongside other concurrent events.
    ///
    /// Use this for time-based operations that require system-actor isolation and cancellation.
    ///
    /// - Parameters:
    ///   - id: Optional identifier used to cancel the task. Auto-generated if `nil`.
    ///   - operation: Async closure that receives the environment, the input proxy, and an
    ///     isolated reference to the system actor.
    ///   - duration: Delay before the operation starts.
    ///   - tolerance: Optional timing tolerance for system optimization.
    ///   - clock: Clock used to measure the delay. Defaults to `ContinuousClock()`.
    ///
    /// > Note: `CancellationError` is ignored; other errors terminate the transducer.
    ///
    /// ## Related Methods
    /// - ``init(action:)-((Env)->Event)`` – Global actor isolation (single event)
    /// - ``init(action:)-((Env)->[Event])`` – Global actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->[Event])`` – System actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->Event)`` – System actor isolation (single event)
    /// - ``init(id:operation:)`` – Async unstructured task on a global actor
    /// - ``init(id:operation:after:tolerance:clock:)``  – Async unstructured task on a global actor
    /// - ``init(id:isolatedOperation:)`` – System actor isolation
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
                // Caution: parameter `systemActor` MUST be *captured* in the
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

    /// **Operation Effect — Global Actor Task (Delayed)**
    ///
    /// Schedules the operation to run as a managed Task on a caller-specified global actor
    /// after a specified delay. Any events must be sent asynchronously via `Input` and are
    /// processed alongside other concurrent events.
    ///
    /// Use this for time-based operations that require a specific global actor and cancellation.
    ///
    /// - Parameters:
    ///   - id: Optional identifier used to cancel the task. Auto-generated if `nil`.
    ///   - operation: Async closure that receives the environment and the input proxy on the
    ///     specified global actor.
    ///   - duration: Delay before the operation starts.
    ///   - tolerance: Optional timing tolerance for system optimization.
    ///   - clock: Clock used to measure the delay. Defaults to `ContinuousClock()`.
    ///
    /// > Note: `CancellationError` is ignored; other errors terminate the transducer.
    ///
    /// ## Related Methods
    /// - ``init(action:)-((Env)->Event)`` – Global actor isolation (single event)
    /// - ``init(action:)-((Env)->[Event])`` – Global actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->[Event])`` – System actor isolation (multiple events)
    /// - ``init(isolatedAction:)-((Env,Actor)->Event)`` – System actor isolation (single event)
    /// - ``init(id:operation:)`` – Async unstructured task on a global actor
    /// - ``init(id:isolatedOperation:)`` – System actor isolation
    /// - ``init(id:isolatedOperation:after:tolerance:clock:)`` – System actor isolation
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
                // Caution: parameter `systemActor` MUST be *captured* in the
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
    
    /// **Action Effect — Immediate Event**
    ///
    /// Emits a single event synchronously in the current computation cycle.
    /// The event is handled before any buffered `Input` events, preserving
    /// ordering and state guarantees.
    ///
    /// - Parameter event: The event to emit immediately.
    /// - Returns: An effect that delivers the event synchronously.
    ///
    /// ## Related Methods
    /// - ``sequence(_:_:)`` – Sequence multiple effects, including event effects
    public static func event(_ event: sending Event) -> Effect {
        Effect(f: { env, input, context, isolated in
            isolated.assertIsolated()
            nonisolated(unsafe) let event = event
            return [event]
        })
    }

}


// MARK: - Action API

extension EffectTransducer {
    
    /// Creates an Action Effect whose action returns an array of events.
    ///
    /// Runs the action on a caller-specified global actor. Events returned from the action
    /// are delivered synchronously during the current computation cycle, before any buffered
    /// `Input` events.
    ///
    /// Use this when you need immediate, in-order processing on a particular global actor,
    /// or when `Env` is isolated to that actor.
    ///
    /// - Parameter action: Async closure that receives the environment on the specified
    ///   global actor. Return zero or more events to be processed immediately.
    ///
    /// > Tip: Minimize captures in the closure for best performance.
    ///
    /// > Caution: Because events are handled synchronously, reaching a terminal state halts
    ///  further processing in this cycle.
    ///
    /// ## Related Methods
    /// - ``action(_:)-((Env)->Event)`` – Caller provided actor (single event)
    /// - ``action(isolatedAction:)-((Env,Actor)->[Event])``– System actor isolation (multiple events)
    /// - ``action(isolatedAction:)-((Env,Actor)->Event)`` – System actor isolation (single event)
    public static func action(
        _ action: @Sendable @escaping @isolated(any) (Env) async throws -> sending [Event]
    ) -> Oak.Effect<Self> where Env: Sendable {
        Effect { env, input, context, systemActor in
            try await action(env)
        }
    }

    /// Creates an Action Effect whose action returns a single event.
    ///
    /// Runs the action on a caller-specified global actor. The event returned from the action
    /// is delivered synchronously during the current computation cycle, before any buffered
    /// `Input` events.
    ///
    /// Use this when you need immediate, in-order processing on a particular global actor,
    /// or when `Env` is isolated to that actor.
    ///
    /// - Parameter action: Async closure that receives the environment on the specified
    ///   global actor. Return a single event to be processed immediately.
    ///
    /// > Tip: Minimize captures in the closure for best performance.
    ///
    /// > Caution: Because events are handled synchronously, reaching a terminal state halts
    ///  further processing in this cycle.
    ///
    /// ## Related Methods
    /// - ``action(_:)-((Env)->[Event])`` – Caller provided actor (multiple events)
    /// - ``action(isolatedAction:)-((Env,Actor)->[Event])`` – System actor isolation (multiple events)
    /// - ``action(isolatedAction:)-((Env,Actor)->Event)`` – System actor isolation (single event)
    public static func action(
        _ action: @Sendable @escaping @isolated(any) (Env) async throws -> sending Event
    ) -> Oak.Effect<Self> where Env: Sendable {
        Effect { env, input, context, systemActor in
            let event = try await action(env)
            return [event]
        }
    }

    /// Creates an Action Effect whose action runs on the given isolator and returns a single event.
    ///
    /// Runs the action on the transducer's system actor and returns a single event.
    /// The event is delivered synchronously during the current computation cycle,
    /// before any buffered `Input` events, regardless of any global-actor isolation on `Env`.
    ///
    /// Use this when you need immediate event processing with the same isolation as the
    /// transducer, or when `Env` is only safe to access from the system actor.
    ///
    /// - Parameter action: Async closure that receives the environment and an isolated
    ///   reference to the system actor. Return a single event to be processed immediately.
    ///
    /// > Tip: Minimize captures in the closure for best performance.
    ///
    /// > Caution: Because events are handled synchronously, reaching a terminal state halts
    /// further processing in this cycle.
    ///
    /// ## Related Methods
    /// - ``action(_:)-((Env)->Event)`` – Caller provided actor (single event)
    /// - ``action(_:)-((Env)->[Event])`` – Caller provided actor (multiple events)
    /// - ``action(isolatedAction:)-((Env,Actor)->[Event])`` – System actor isolation (multiple events)
    public static func action(
        isolatedAction action: @Sendable @escaping (
            Env,
            isolated any Actor
        ) async throws -> sending Event
    ) -> Oak.Effect<Self> {
        Effect { env, input, context, systemActor in
            let event = try await action(env, systemActor)
            return [event]
        }
    }

    
    /// Creates an Action Effect whose action runs on the given isolator and returns an array of events.
    ///
    /// Runs the action on the same actor as the transducer's run loop (the “system actor”),
    /// independent of any global-actor isolation on `Env`. Events returned from the action
    /// are delivered synchronously during the current computation cycle, before any buffered
    /// `Input` events.
    ///
    /// Use this when you need immediate, in-order processing with the same isolation as the
    /// transducer, or when `Env` is only safe to access from the system actor.
    ///
    /// - Parameter action: Async closure that receives the environment and an isolated
    ///   reference to the system actor. Return zero or more events to be processed immediately.
    ///
    /// > Tip: Minimize captures in the closure for best performance.
    ///
    /// > Caution: Because events are handled synchronously, reaching a terminal state halts
    ///  further processing in this cycle.
    ///
    /// ## Related Methods
    /// - ``action(_:)-((Env)->Event)``
    /// - ``action(_:)-((Env)->[Event])``
    /// - ``action(isolatedAction:)-((Env,Actor)->Event)`` – System actor isolation (single event)
    public static func action(
        isolatedAction action: @Sendable @escaping (
            Env,
            isolated any Actor
        ) async throws -> sending [Event]
    ) -> Oak.Effect<Self> {
        Effect { env, input, context, systemActor in
            try await action(env, systemActor)
        }
    }
}

// MARK: Sequence API

extension Effect {

    /// **Effect Sequencing - Sequential Execution**
    ///
    /// Sequences two effects into a single effect that executes them sequentially.
    /// Events from both effects are collected and returned together.
    ///
    /// Effects execute in order with their events sequenced into a single result.
    /// If any effect throws an error, the sequenced effect terminates immediately.
    ///
    /// - Parameters:
    ///   - effect1: The first effect to execute.
    ///   - effect2: The second effect to execute.
    /// - Returns: A sequenced effect that executes both sequentially.
    ///
    /// ## Related Methods
    /// - ``sequence(_:_:_:)`` - For sequencing three effects
    /// - ``sequence(_:_:_:_:)`` - For sequencing four effects
    /// - ``sequence(_:_:_:_:_:)`` - For sequencing five effects
    public static func sequence(
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

    /// **Effect Sequencing - Sequential Execution**
    ///
    /// Sequences three effects into a single effect that executes them sequentially.
    /// Events from all effects are collected and returned together.
    ///
    /// Effects execute in order with their events sequenced into a single result.
    /// If any effect throws an error, the sequenced effect terminates immediately.
    ///
    /// - Parameters:
    ///   - effect1: The first effect to execute.
    ///   - effect2: The second effect to execute.
    ///   - effect3: The third effect to execute.
    /// - Returns: A sequenced effect that executes all three sequentially.
    ///
    /// ## Related Methods
    /// - ``sequence(_:_:)`` - For sequencing two effects
    /// - ``sequence(_:_:_:_:)`` - For sequencing four effects
    /// - ``sequence(_:_:_:_:_:)`` - For sequencing five effects
    public static func sequence(
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

    /// **Effect Sequencing - Sequential Execution**
    ///
    /// Sequences four effects into a single effect that executes them sequentially.
    /// Events from all effects are collected and returned together.
    ///
    /// Effects execute in order with their events sequenced into a single result.
    /// If any effect throws an error, the sequenced effect terminates immediately.
    ///
    /// - Parameters:
    ///   - effect1: The first effect to execute.
    ///   - effect2: The second effect to execute.
    ///   - effect3: The third effect to execute.
    ///   - effect4: The fourth effect to execute.
    /// - Returns: A sequenced effect that executes all four sequentially.
    ///
    /// ## Related Methods
    /// - ``sequence(_:_:)`` - For sequencing two effects
    /// - ``sequence(_:_:_:)`` - For sequencing three effects
    /// - ``sequence(_:_:_:_:_:)`` - For sequencing five effects
    public static func sequence(
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

    /// **Effect Sequencing - Sequential Execution**
    ///
    /// Sequences five effects into a single effect that executes them sequentially.
    /// Events from all effects are collected and returned together.
    ///
    /// Effects execute in order with their events sequenced into a single result.
    /// If any effect throws an error, the sequenced effect terminates immediately.
    ///
    /// - Parameters:
    ///   - effect1: The first effect to execute.
    ///   - effect2: The second effect to execute.
    ///   - effect3: The third effect to execute.
    ///   - effect4: The fourth effect to execute.
    ///   - effect5: The fifth effect to execute.
    /// - Returns: A sequenced effect that executes all five sequentially.
    ///
    /// ## Related Methods
    /// - ``sequence(_:_:)`` - For sequencing two effects
    /// - ``sequence(_:_:_:)`` - For sequencing three effects
    /// - ``sequence(_:_:_:_:)`` - For sequencing four effects
    public static func sequence(
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

    /// **Task Cancellation - Operation Management**
    ///
    /// Creates an effect that cancels a previously created operation by its identifier.
    /// Use in the `update` function to explicitly terminate running operations.
    ///
    /// Enables fine-grained control over operation lifecycles by targeting specific
    /// tasks for immediate cancellation without affecting other concurrent operations.
    ///
    /// - Parameter id: The identifier of the task to cancel.
    /// - Returns: An effect that cancels the specified task.
    ///
    /// ## Related Methods
    /// - ``init(id:operation:)`` - For creating cancellable operations with global actor
    /// - ``init(id:isolatedOperation:)`` - For creating cancellable operations with system actor
    /// - ``init(id:operation:after:tolerance:clock:)`` - For creating cancellable timed operations
    ///
    public static func cancelTask(_ id: some Hashable & Sendable) -> Effect {
        return Effect(f: { env, input, context, isolated in
            context.cancelTask(id: ID(id), isolated: isolated)
            return []
        })
    }
}

