import Testing
import Foundation
import Oak

/// This test suite verifies that transducers can be cancelled correctly.
/// 
/// A transducer can be cancelled through its proxy calling the `cancel()`
/// method in which case the transducer throws a `TransducerError`.
/// The `run` function will also perform a clean up when the current Task
/// has been cancelled and it will throw a `CancellationError`.
///
/// A transducer can basically be in the following states:
/// 1. It is idle, meaning it is not processing any events.
/// 2. It is waiting for an output to be written, i.e. it is suspended.
/// 3. It is in any of the states above, but in addition it is 
///    executing one or more effects which run asynchronously and 
///    it waits for their completion.
/// 
/// When a transducer is cancelled, it should not process any further events.
/// In addition, it should cancel from the suspended state, if it is
/// waiting for an output to be written. If there are running effects,
/// they must be cancelled as well.
/// 
/// When the current Task has been cancelled, the transducer will be forcibly 
/// terminated, and it should throw a `CancellationError`.
/// 
/// When the transducer has been cancelled, via its proxy, the transducer 
/// should be forcibly terminated and it should throw a 
/// `TransducerError.cancelled` error from its `run` function.
struct TransducerCancellationTests {
    
    // MARK: - Transducers
    
    @MainActor
    @Test
    func cancelIdleNonTerminatingTransducerViaProxy() async throws {
        enum T: Transducer {
            enum State: NonTerminal { case start, idle }
            enum Event { case start }
            
            static func update(_ state: inout State, event: Event) {
                switch (state, event) {
                case (.start, .start):
                    state = .idle
                default:
                    break
                }
            }
        }
        
        let proxy = T.Proxy()
        try proxy.send(.start)
        let task = Task {
            try await T.run(initialState: .start, proxy: proxy)
        }
        try await Task.sleep(nanoseconds: 1_000_000)
        // Given:
        //  - the event buffer is empty
        //  - the transducer is idle
        // Then cancel:
        proxy.cancel()
        
        let error = await #expect(throws: TransducerError.self) {
            try await task.value
        }
        #expect(error == TransducerError.cancelled)
    }
    
    @MainActor
    @Test
    func ensureIdleTransducerWillCancelWhenCurrentTaskIsCancelled() async throws {
        enum T: Transducer {
            enum State: Terminable { case start, idle, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start }

            static func update(_ state: inout State, event: Event) {
                if state == .start, event == .start {
                    state = .idle
                }
            }
        }

        let proxy = T.Proxy()
        try proxy.send(.start)
        let task = Task {
            try await T.run(initialState: .start, proxy: proxy)
        }
        // Give the run loop time to process the start event
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    // MARK: - Effect Transducers
    
    @MainActor
    @Test("not implemented: a proxy cannot cancel an async action", .disabled())
    func cancelSuspendedEffectTransducerWhenInSuspendedActionViaProxy() async throws {
        enum T: EffectTransducer {
            enum State: Terminable { case start, idle, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, ready }

            struct Env {}
            
            typealias Output = Void
            
            static func update(_ state: inout State, event: Event) -> Self.Effect? {
                switch (state, event) {
                case (.start, .start):
                    return makeActionEffect()
                case (.start, .ready):
                    state = .idle
                    return nil
                case (.finished, _):
                    return nil
                default:
                    return nil
                }
            }

            static func makeActionEffect() -> T.Effect {
                T.Effect(
                    action: { _ in
                        do {
                            try await Task.sleep(nanoseconds: 100_000_000_000) // 100 seconds
                            #expect(Bool(false), "Effect should have been cancelled")
                            return [.ready]
                        } catch {
                            #expect(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
                            throw error // Re-throw to propagate the cancellation
                        }
                    }
                )
            }
        }
        
        let proxy = T.Proxy()
        try proxy.send(.start)
        let task = Task {
            try await T.run(
                initialState: .start,
                proxy: proxy,
                env: T.Env()
            )
        }
        Task {
            try await Task.sleep(nanoseconds: 1_000_000)
            // Given:
            //  - the event buffer contains a number of events
            //  - the transducer is waiting for the output
            // Then cancel:
            proxy.cancel()
        }
        let error = await #expect(throws: TransducerError.self) {
            try await task.value
        }
        #expect(error == TransducerError.cancelled)
    }

    @MainActor
    @Test("not implemented: a proxy cannot cancel an async output subject", .disabled())
    func cancelSuspendedEffectTransducerWhenSuspendedInOutputViaProxy() async throws {
        enum T: EffectTransducer {
            enum State: Terminable { case start, idle, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, ready }

            struct Env {}
            
            typealias Output = Int
            
            static func update(_ state: inout State, event: Event) -> (Self.Effect?, Output) {
                switch (state, event) {
                case (.start, .start):
                    return (makeActionEffect(), 1)
                case (.start, .ready):
                    state = .idle
                    return (nil, 2)
                case (.finished, _):
                    return (nil, -1)
                default:
                    return (nil, -2)
                }
            }

            static func makeActionEffect() -> T.Effect {
                T.Effect(
                    action: { _ in
                        do {
                            try await Task.sleep(nanoseconds: 100_000_000_000) // 100 seconds
                            #expect(Bool(false), "Effect should have been cancelled")
                            return [.ready]
                        } catch {
                            #expect(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
                            throw error // Re-throw to propagate the cancellation
                        }
                    }
                )
            }
        }
        
        let proxy = T.Proxy()
        try proxy.send(.start)
        let task = Task {
            try await T.run(
                initialState: .start,
                proxy: proxy,
                env: T.Env(),
                output: Callback { @MainActor output in
                    print("Output: \(output)")
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            )
        }
        Task {
            try await Task.sleep(nanoseconds: 1_000_000)
            // Given:
            //  - the event buffer contains a number of events
            //  - the transducer is waiting for the output
            // Then cancel:
            proxy.cancel()
        }
        let error = await #expect(throws: TransducerError.self) {
            try await task.value
        }
        #expect(error == TransducerError.cancelled)
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @MainActor
    @Test
    func cancelIdleEffectTransducerWhenRunningAsynchronousEffectsWithOutputViaProxy() async throws {
        enum T: EffectTransducer {
            
            enum State: Terminable { 
                case start, idle, waiting, finished
                var isTerminal: Bool { self == .finished }
            }
            
            enum Event { case start, ready }
            
            struct Output {
                let value: Int
                let isWaiting: Bool
            }
            
            struct Env {
                let effectStarted = Expectation()
                let expectOutput = Expectation()
                let expectCancelled = Expectation()
            }
            
            static func update(_ state: inout State, event: Event) -> (T.Effect?, Output) {
                switch (state, event) {
                case (.start, .start):
                    state = .waiting
                    return (makeOperationEffect(), Output(value: 0, isWaiting: true))
                case (.waiting, .ready):
                    state = .idle
                    return (nil, Output(value: 0, isWaiting: false))
                case (.idle, .start):
                    return (nil, Output(value: 3, isWaiting: false))
                case (.finished, _):
                    return (nil, Output(value: -1, isWaiting: false))

                case (.idle, .ready):
                    return (nil, Output(value: 0, isWaiting: false))
                case (.start, .ready):
                    return (nil, Output(value: 0, isWaiting: false))
                case (.waiting, .start):
                    return (nil, Output(value: 0, isWaiting: true))
                }
            }

            static func makeOperationEffect() -> T.Effect {
                T.Effect(
                    operation: { env, input in
                        do {
                            env.effectStarted.fulfill()
                            while true {
                                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconds
                            }
                            #expect(Bool(false), "Effect should have been cancelled")
                            try input.send(.ready)
                        } catch {
                            env.expectCancelled.fulfill()
                            #expect(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
                            throw error // Re-throw to propagate the cancellation
                        }
                    }
                )
            }
        }
        
        let proxy = T.Proxy()
        try proxy.send(.start) // This should trigger the long-running effect
        let env = T.Env()
        
        let task = Task {
            try await T.run(
                initialState: .start,
                proxy: proxy,
                env: env,
                output: Callback { @MainActor output in
                    if output.isWaiting {
                        env.expectOutput.fulfill()
                    }
                }
            )
        }
        
        Task {
            try await env.effectStarted.await(timeout: .seconds(10))
            // Given:
            //  - the event buffer contains no events
            //  - the transducer is running a long-running effect (waiting 100 seconds)
            // Then cancel:
            proxy.cancel()
        }
        try await env.expectCancelled.await(timeout: .seconds(10000))
        try await env.expectOutput.await(timeout: .seconds(10000))
        let error = await #expect(throws: TransducerError.self) {
            try await task.value
        }
        #expect(error == TransducerError.cancelled)
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @MainActor
    @Test
    func cancelIdleEffectTransducerWhenRunningAsynchronousEffectsViaProxy() async throws {
        enum T: EffectTransducer {
            
            enum State: Terminable {
                case start, idle, waiting, finished
                var isTerminal: Bool { self == .finished }
            }
            
            enum Event { case start, ready }
            
            struct Env {
                let effectStarted = Expectation()
                let effectCancelled = Expectation()
            }
            
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch (state, event) {
                case (.start, .start):
                    state = .waiting
                    return makeEffect()
                case (.waiting, .ready):
                    state = .idle
                    return nil
                case (.idle, .start):
                    return nil
                case (.finished, _):
                    return nil
                case (.idle, .ready):
                    return nil
                case (.start, .ready):
                    return nil
                case (.waiting, .start):
                    return nil
                }
            }

            static func makeEffect() -> T.Effect {
                T.Effect(
                    operation: { env, input in
                        do {
                            env.effectStarted.fulfill()
                            while true {
                                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconds
                            }
                            #expect(Bool(false), "Effect should have been cancelled")
                            try input.send(.ready)
                        } catch {
                            // When a transducer gets cancelled, it's operations
                            // running in a task. This task will be cancelld, so
                            // we get a `CancellationError`
                            env.effectCancelled.fulfill()
                            #expect(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
                            throw error // Re-throw to propagate the cancellation
                        }
                    }
                )
            }
        }
        
        let proxy = T.Proxy()
        try proxy.send(.start) // This should trigger the long-running effect
        let env = T.Env()
        
        let task = Task {
            try await T.run(
                initialState: .start,
                proxy: proxy,
                env: env
            )
        }
        
        Task {
            try await env.effectStarted.await(timeout: .seconds(10))
            // Given:
            //  - the event buffer contains no events
            //  - the transducer is running a long-running effect (waiting 100 seconds)
            // Then cancel:
            proxy.cancel()
        }
        try await env.effectCancelled.await(timeout: .seconds(10))
        let error = await #expect(throws: TransducerError.self) {
            try await task.value
        }
        #expect(error == TransducerError.cancelled)
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @MainActor
    @Test
    func cancelIdleEffectTransducerWhenRunningAsynchronousEffectsWhenCurrentTaskIsCancelled() async throws {
        enum T: EffectTransducer {
            
            enum State: Terminable {
                case start, idle, waiting, finished
                var isTerminal: Bool { self == .finished }
            }
            
            enum Event { case start, ready }
            
            struct Env {
                let effectStarted = Expectation()
                let effectCancelled = Expectation()
            }
            
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch (state, event) {
                case (.start, .start):
                    state = .waiting
                    return makeEffect()
                case (.waiting, .ready):
                    state = .idle
                    return nil
                case (.idle, .start):
                    return nil
                case (.finished, _):
                    return nil
                case (.idle, .ready):
                    return nil
                case (.start, .ready):
                    return nil
                case (.waiting, .start):
                    return nil
                }
            }

            static func makeEffect() -> T.Effect {
                T.Effect(
                    operation: { env, input in
                        do {
                            env.effectStarted.fulfill()
                            while true {
                                try await Task.sleep(nanoseconds: 100_000_000_000) // 100 seconds
                            }
                            #expect(Bool(false), "Effect should have been cancelled")
                            try input.send(.ready)
                        } catch {
                            env.effectCancelled.fulfill()
                            #expect(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
                            throw error // Re-throw to propagate the cancellation
                        }
                    }
                )
            }
        }
        
        let proxy = T.Proxy()
        try proxy.send(.start) // This should trigger the long-running effect
        let env = T.Env()
        
        let task = Task {
            try await T.run(
                initialState: .start,
                proxy: proxy,
                env: env
            )
            print("done")
        }
        
        try await env.effectStarted.await(timeout: .seconds(10))
        // Given:
        //  - the event buffer contains no events
        //  - the transducer is running a long-running effect (waiting 100 seconds)
        // Then cancel the task:
        Task {
            task.cancel()
        }

        try await env.effectCancelled.await(timeout: .seconds(10))
        
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @MainActor
    @Test
    func cancelIdleEffectTransducerWhenRunningAsynchronousEffectsWithOutputWhenCurrentTaskIsCancelled() async throws {
        enum T: EffectTransducer {
            
            enum State: Terminable {
                case start, idle, waiting, finished
                var isTerminal: Bool { self == .finished }
            }
            
            enum Event { case start, ready }
            
            struct Env {
                let effectStarted = Expectation()
                let effectCancelled = Expectation()
            }
            
            typealias Output = Int
            
            static func update(_ state: inout State, event: Event) -> (T.Effect?, Output) {
                switch (state, event) {
                case (.start, .start):
                    state = .waiting
                    return (makeEffect(), 0)
                case (.waiting, .ready):
                    state = .idle
                    return (nil, 1)
                case (.idle, .start):
                    return (nil, 2)
                case (.finished, _):
                    return (nil, 3)
                case (.idle, .ready):
                    return (nil, 4)
                case (.start, .ready):
                    return (nil, 5)
                case (.waiting, .start):
                    return (nil, 6)
                }
            }

            static func makeEffect() -> T.Effect {
                T.Effect(
                    operation: { env, input in
                        do {
                            env.effectStarted.fulfill()
                            while true {
                                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconds
                            }
                            #expect(Bool(false), "Effect should have been cancelled")
                            try input.send(.ready)
                        } catch {
                            env.effectCancelled.fulfill()
                            #expect(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
                            throw error // Re-throw to propagate the cancellation
                        }
                    }
                )
            }
        }
        
        let proxy = T.Proxy()
        try proxy.send(.start) // This should trigger the long-running effect
        let env = T.Env()
        
        let task = Task {
            try await T.run(
                initialState: .start,
                proxy: proxy,
                env: env
            )
        }
        
        try await env.effectStarted.await(timeout: .seconds(10))
        // Given:
        //  - the event buffer contains no events
        //  - the transducer is running a long-running effect (waiting 100 seconds)
        // Then cancel the task:
        Task {
            task.cancel()
        }

        try await env.effectCancelled.await(timeout: .seconds(10))
        
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @MainActor
    @Test
    func ensureIdleEffectTransducerWillCancelWhenCurrentTaskIsCancelled() async throws {
        enum T: EffectTransducer {
            enum State: Terminable { case start, idle, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start }
            struct Env {}

            static func update(_ state: inout State, event: Event) -> Self.Effect? {
                if state == .start, event == .start {
                    state = .idle
                }
                return nil
            }
        }

        let proxy = T.Proxy()
        try proxy.send(.start)
        let task = Task {
            try await T.run(initialState: .start, proxy: proxy, env: T.Env())
        }
        // Give the run loop time to process the start event
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @MainActor
    @Test
    func ensureSuspendedEffectTransducerWillCancelWhenCurrentTaskIsCancelled() async throws {
        enum T: EffectTransducer {
            enum State: Terminable { case start, idle, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, ready }
            struct Env {
                let effectStarted = Expectation()
                let effectCancelled = Expectation()
            }

            static func update(_ state: inout State, event: Event) -> Self.Effect? {
                if state == .start, event == .start {
                    state = .idle
                    return T.Effect(action: { env in
                        do {
                            env.effectStarted.fulfill()
                            while true {
                                try await Task.sleep(nanoseconds: 1_000_000_000)
                            }
                            // Should never reach here
                            #expect(Bool(false), "Effect action should have been cancelled before completion")
                            return [.ready]
                        } catch {
                            #expect(error is CancellationError, "Expected CancellationError in effect action, got \(type(of: error))")
                            env.effectCancelled.fulfill()
                            throw error
                        }
                    })
                }
                return nil
            }
        }

        let proxy = T.Proxy()
        try proxy.send(.start)
        let env = T.Env()
        let task = Task {
            try await T.run(initialState: .start, proxy: proxy, env: env)
        }
        // wait until the effect started:
        try await env.effectStarted.await(timeout: .seconds(10))
        // Cancel the outer task
        task.cancel()

        try await env.effectCancelled.await(timeout: .seconds(10))
        // The run function should throw a CancellationError
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @MainActor
    @Test
    func ensureIdleEffectTransducerWithRunningEffectWillCancelWhenCurrentTaskIsCancelled() async throws {
        
        enum T: EffectTransducer {
            enum State: Terminable {
                case start, idle, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, ready }
            struct Env {
                let effectStarted = Expectation()
                let effectCancelled = Expectation()
            }

            static func update(_ state: inout State, event: Event) -> Self.Effect? {
                switch (state, event) {
                case (.start, .start):
                    state = .idle
                    return Effect { env, input in
                        do {
                            env.effectStarted.fulfill()
                            // Suspend for 1 second
                            while true {
                                // We effectively check for cancellation every 1 sec
                                try await Task.sleep(nanoseconds: 1_000_000_000)
                            }
                            // Should never get here
                            #expect(Bool(false), "Effect operation should have been cancelled before completing")
                            try input.send(.ready)
                        } catch {
                            // Expect a CancellationError when task is cancelled
                            #expect(error is CancellationError, "Expected CancellationError in effect, got \(type(of: error))")
                            env.effectCancelled.fulfill()
                            throw error
                        }
                    }

                default:
                    return nil
                }
            }
        }

        let proxy = T.Proxy()
        try proxy.send(.start)
        let env = T.Env()

        let task = Task {
            try await T.run(initialState: .start, proxy: proxy, env: env)
        }
        
        // Give the transducer time to start the effect
        try await env.effectStarted.await(timeout: .seconds(10))
        // Cancel the outer task
        task.cancel()

        try await env.effectCancelled.await(timeout: .seconds(10))
        // The run() should throw a CancellationError
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
    
    @MainActor
    @Test
    func ensureIdleEffectTransducerWithOutputWillCancelWhenCurrentTaskIsCancelled() async throws {
        enum T: EffectTransducer {
            enum State: Terminable { case start, idle, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start }
            struct Env {}
            typealias Output = Int

            static func update(_ state: inout State, event: Event) -> (Self.Effect?, Output) {
                if state == .start, event == .start {
                    state = .idle
                }
                return (nil, 0)
            }
        }

        let proxy = T.Proxy()
        try proxy.send(.start)
        let env = T.Env()
        let task = Task {
            try await T.run(initialState: .start, proxy: proxy, env: env)
        }
        // Give the run loop time to process the start event
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

}
