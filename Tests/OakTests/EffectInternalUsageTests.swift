import Testing
import Foundation

#if DEBUG
@testable import FSM

/// EffectInternalUsageTests
///
/// This test suite verifies the correct construction, execution, and isolation of effects within transducers.
/// It may access internal functions and types.
///
/// The tests cover:
/// - Creation of effects using various initializers (primary, async, action, operation, and event-based).
/// - Correct event handling and state transitions within the transducer.
/// - Proper actor or global actor isolation for effect execution, ensuring thread safety and preventing data
/// races.
/// - Thread-safety of environment mutation, with explicit tests designed to be run under Thread Sanitizer
/// (TSAN).
/// - Handling of actor-isolated environments and payloads.
///
/// These tests ensure that the transducer and effect system works as intended in both synchronous and
/// asynchronous contexts, and that isolation boundaries are respected throughout effect execution.
struct EffectInternalUsageTests {

    @TestGlobalActor
    @Test
    func createEffectWithPrimaryInitialiser() async throws {
        
        enum T: EffectTransducer {
            class Env { var value: Int = 0 }
            class Payload { var value: Int = 0 }
            enum State: Terminable { case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload) }
            
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    let effect = T.Effect { env, input, context, systemActor in
                        #expect(TestGlobalActor.shared === systemActor)
                        systemActor.assertIsolated()
                        let payload = T.Payload()
                        try input.send(.payload(payload))
                        return []
                    }
                    return effect
                    
                case .payload(let payload):
                    _ = payload.self
                    state = .finished
                    return nil
                }
            }
            
            typealias Proxy = FSM.Proxy<Event>
        }
        
        let env = T.Env()
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: env)
    }
    
    @TestGlobalActor
    @Test
    func createEffectWithPrimaryInitialiserAsync() async throws {
        
        enum T: EffectTransducer {
            class Env { var value: Int = 0 }
            class Payload { var value: Int = 0 }
            enum State: Terminable { case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload) }
            
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    return effect()
                    
                case .payload(let payload):
                    _ = payload.self
                    state = .finished
                    return nil
                }
            }
            
            static func effect() -> T.Effect {
                T.Effect { env, input, context, systemActor in
                    #expect(TestGlobalActor.shared === systemActor)
                    systemActor.assertIsolated()
                    try await Task.sleep(nanoseconds: 1_000_000)
                    let payload = T.Payload()
                    try input.send(.payload(payload))
                    return []
                }
            }
        }
        
        let env = T.Env()
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: env)
    }
    
    /// This test is primarily designed to test thread-safety.
    /// The test alters `env` which should not race. Enable TSAN diagnostics for this test.
    @TestGlobalActor
    @Test
    func testTSAN() async throws {
        
        enum T: EffectTransducer {
            class Env { init(_ value: Int = 0) { self.value = value }; var value: Int }
            class Payload { init(_ value: Int = 0) { self.value = value }; var value: Int }
            enum State: Terminable, Equatable { case start, active(Int), finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload) }
            
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch (event, state) {
                case (.start, .start):
                    state = .active(1)
                    return fetchPayload()
                    
                    
                case (.payload(let payload), .active(let value)) where payload.value == 0:
                    _ = payload.self
                    _ = value.self
                    state = .finished
                    return nil
                    
                case (.payload(_), .active(let value)):
                    state = .active(value + 1)
                    return fetchPayload()
                    
                case (_, _):
                    fatalError("invalid transition")
                }
            }
            
            static func fetchPayload() -> T.Effect {
                T.Effect { env, input, context, systemActor in
                    #expect(TestGlobalActor.shared === systemActor)
                    systemActor.assertIsolated()
                    try await Task.sleep(nanoseconds: 1_000_000)
                    let payload = T.Payload(env.value)
                    try input.send(.payload(payload))
                    return []
                }
            }
        }
        
        let env = T.Env(1)
        Task {
            try await Task.sleep(nanoseconds: 1_000_000)
            env.value = 0
        }
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: env)
    }

}

/// Verify correct implementation of class `Context`.
///
/// A context instance is created only when using an EffectTransducer.
/// The context maintains a dictionary of tasks. A task is created when
/// invoking an operation effect. Note, that an action effect does not
/// access the context, as it does never create a task.
///
/// The test suite should verify, that when an operation will be invoked,
/// it's task should have been "registered" in the context, i.e. it has been
/// inserted into the context's task dictionary with the specified
/// identifier. 
/// 
/// It should also verify, that when a Task will be registered with an `id`
/// an existing task with the same identifier will be cancelled before the
/// new task will be registered, which also removes the former task from
/// the dictionary.
///
/// It also verifies, that when a task will be _completed_, it will be removed
/// from the context's task dictionary _only_ if it matches the identifier
/// _and_ the task itself. This is to prevent removing a task which was
/// registered with the same identifier and which cancelled this task. The
/// now existing task is considered the actual running task with this id. The
/// task which is attempted to be removed was the former task which has
/// been cancelled and has already been removed by the replacing task.
/// This can happen in same (valid) race conditions, as Swift Tasks don't
/// guarantee an execution order.
struct InternalContextTests {

    @TestGlobalActor
    @Test
    func verifyThatAnOperationWithIdWillBeRegisteredInTheContext() async throws {
        enum T: EffectTransducer {
            class Env {}
            enum State: Terminable { case start, spying, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, spy, done }
            
            // Use a static property to store the operation ID
            static let operationID = UUID()
            static let wrappedOperationID = ID(operationID)
            
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    // Create an operation effect that will keep running
                    let operationEffect = T.Effect(id: operationID, isolatedOperation: { env, input, systemActor in
                        // This operation will trigger the spy event and then wait
                        try input.send(.spy)
                        
                        // Keep the operation running so it stays in the context
                        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 secs
                    })
                    
                    state = .spying
                    return operationEffect
                    
                case .spy:
                    // Create a spy effect using the internal init to observe context
                    return T.Effect(f: { env, input, context, systemActor in
                        // Spy on the context state
                        // 1. Expect that there is exactly one task running
                        #expect(context.tasks.count == 1, "Context should contain exactly one task")
                        
                        // 2. Expect that the task corresponds to our operation ID
                        #expect(context.tasks[wrappedOperationID] != nil, "Task should be registered with the specified ID")
                        
                        // Signal completion
                        try input.send(.done)
                        return []
                    })
                    
                case .done:
                    state = .finished
                    return nil
                }
            }
            
            typealias Proxy = FSM.Proxy<Event>
        }
        
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: T.Env())
    }

    @TestGlobalActor
    @Test
    func verifyThatANewTaskWithSameIdWillCancelTheExistingTask() async throws {
        enum T: EffectTransducer {
            class Env {}
            enum State: Terminable { case start, spying, secondOperation, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, spy, startSecond, done }
            
            // Use the same ID for both operations to test cancellation behavior
            static let operationID = UUID()
            static let wrappedOperationID = ID(operationID)
            
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    // Create first operation effect that will keep running
                    let firstOperation = T.Effect(id: operationID, isolatedOperation: { env, input, systemActor in
                        // This operation should be cancelled by the second operation
                        try input.send(.spy)
                        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 secs // This should be cancelled
                    })
                    
                    state = .spying
                    return firstOperation
                    
                case .spy:
                    // Spy to verify first task is registered, then trigger second operation
                    return T.Effect(f: { env, input, context, systemActor in
                        // Verify first task is registered
                        #expect(context.tasks.count == 1, "Context should contain exactly one task")
                        #expect(context.tasks[wrappedOperationID] != nil, "First task should be registered")
                        
                        // Trigger second operation with same ID
                        try input.send(.startSecond)
                        return []
                    })
                    
                case .startSecond:
                    // Create second operation with same ID - should cancel the first
                    let secondOperation = T.Effect(id: operationID, isolatedOperation: { env, input, systemActor in
                        // Small delay to ensure we can observe the replacement
                        try await Task.sleep(nanoseconds: 10_000_000) // 10 ms
                        try input.send(.done)
                    })
                    
                    state = .secondOperation
                    return secondOperation
                    
                case .done:
                    state = .finished
                    return nil
                }
            }
            
            typealias Proxy = FSM.Proxy<Event>
        }
        
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: T.Env())
    }

    @TestGlobalActor
    @Test
    func verifyThatCompletedTaskIsRemovedFromContext() async throws {
        enum T: EffectTransducer {
            class Env {}
            enum State: Terminable { case start, spying, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, spy, operationComplete, done }
            
            static let operationID = UUID()
            static let wrappedOperationID = ID(operationID)
            
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    // Create operation that completes quickly
                    let operation = T.Effect(id: operationID, isolatedOperation: { env, input, systemActor in
                        // Trigger spy first, then complete
                        try input.send(.spy)
                        // Short operation that will complete
                        try await Task.sleep(nanoseconds: 10_000_000) // 10 ms
                        try input.send(.operationComplete)
                    })
                    
                    state = .spying
                    return operation
                    
                case .spy:
                    // Spy to verify task is registered while running
                    return T.Effect(f: { env, input, context, systemActor in
                        #expect(context.tasks.count == 1, "Context should contain exactly one task while operation is running")
                        #expect(context.tasks[wrappedOperationID] != nil, "Task should be registered while running")
                        return []
                    })
                    
                case .operationComplete:
                    // Spy again to verify task was removed after completion
                    return T.Effect(f: { env, input, context, systemActor in
                        // Small delay to ensure cleanup has occurred
                        try await Task.sleep(nanoseconds: 5_000_000) // 5 ms
                        #expect(context.tasks.count == 0, "Context should be empty after task completion")
                        #expect(context.tasks[wrappedOperationID] == nil, "Completed task should be removed from context")
                        
                        try input.send(.done)
                        return []
                    })
                    
                case .done:
                    state = .finished
                    return nil
                }
            }
            
            typealias Proxy = FSM.Proxy<Event>
        }
        
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: T.Env())
    }

    @TestGlobalActor
    @Test
    func verifyThatOnlyCorrectTaskIsRemovedDuringRaceCondition() async throws {
        enum T: EffectTransducer {
            class Env {}
            enum State: Terminable { case start, spying, secondTaskCreated, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, spy, createSecond, secondCreated, done }
            
            static let operationID = UUID()
            static let wrappedOperationID = ID(operationID)
            
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    // Create first operation that will be replaced
                    let firstOperation = T.Effect(id: operationID, isolatedOperation: { env, input, systemActor in
                        try input.send(.spy)
                        // This should be cancelled before completing
                        try await Task.sleep(nanoseconds: 10_000_000_000) // 10 secs
                    })
                    
                    state = .spying
                    return firstOperation
                    
                case .spy:
                    // Verify first task exists, then create second task
                    return T.Effect(f: { env, input, context, systemActor in
                        #expect(context.tasks.count == 1, "Should have first task")
                        
                        try input.send(.createSecond)
                        return []
                    })
                    
                case .createSecond:
                    // Create second task with same ID (should cancel first)
                    let secondOperation = T.Effect(id: operationID, isolatedOperation: { env, input, systemActor in
                        // Small delay to ensure task registration is complete
                        try await Task.sleep(nanoseconds: 1_000_000) // 1 ms
                        try input.send(.secondCreated)
                        // This task completes quickly
                        try await Task.sleep(nanoseconds: 10_000_000) // 10 ms
                        // After this completes, the context should be empty
                    })
                    
                    state = .secondTaskCreated
                    return secondOperation
                    
                case .secondCreated:
                    // Verify only the second task exists
                    return T.Effect(f: { env, input, context, systemActor in
                        #expect(context.tasks.count == 1, "Should still have exactly one task (the second one)")
                        #expect(context.tasks[wrappedOperationID] != nil, "Second task should be registered")
                        
                        // Wait for second task to complete and verify cleanup
                        try await Task.sleep(nanoseconds: 50_000_000) // 50 ms
                        #expect(context.tasks.count == 0, "Context should be empty after second task completes")
                        
                        try input.send(.done)
                        return []
                    })
                    
                case .done:
                    state = .finished
                    return nil
                }
            }
            
            typealias Proxy = FSM.Proxy<Event>
        }
        
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: T.Env())
    }

}


#endif
