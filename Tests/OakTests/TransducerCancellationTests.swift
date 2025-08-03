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

    @Suite
    struct CancellationViaProxy {
        @MainActor
        @Test
        func cancelIdleNonTerminatingTransducer() async throws {
            enum T: Transducer {
                enum State: NonTerminal { case start, idle }
                enum Event { case start }
                static func update(_ state: inout State, event: Event) { state = .idle }
            }
            let proxy = T.Proxy()
            try proxy.send(.start)
            let task = Task {
                try await T.run(initialState: .start, proxy: proxy)
            }
            await Task.yield()
            proxy.cancel()
            let error = await #expect(throws: TransducerError.self) {
                try await task.value
            }
            #expect(error == .cancelled)
        }
        
                @MainActor
        @Test("not implemented: a proxy cannot cancel an async action", .disabled())
        func cancelSuspendedEffectTransducerWhenInSuspendedAction() async throws {
            enum T: EffectTransducer {
                enum State: Terminable { 
                    case start, idle, finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start, ready }
                struct Env {}
                
                static func update(_ state: inout State, event: Event) -> Self.Effect? {
                    guard state == .start && event == .start else { return nil }
                    return Effect(action: { _ in
                        try await Task.sleep(for: .seconds(100)) // Long sleep
                        #expect(Bool(false), "Effect should have been cancelled")
                        return [.ready]
                    })
                }
            }
            
            let proxy = T.Proxy()
            try proxy.send(.start)
            
            let task = Task {
                try await T.run(initialState: .start, proxy: proxy, env: T.Env())
            }
            
            // Cancel after a brief delay
            Task {
                try await Task.sleep(for: .milliseconds(1))
                proxy.cancel()
            }
            
            let error = await #expect(throws: TransducerError.self) {
                try await task.value
            }
            #expect(error == .cancelled)
        }
        

        @MainActor
        @Test("not implemented: a proxy cannot cancel an async output subject", .disabled())
        func cancelSuspendedEffectTransducerWhenSuspendedInOutput() async throws {
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
        func cancelIdleEffectTransducerWhenRunningAsynchronousEffectsWithOutput() async throws {
            enum T: EffectTransducer {
                enum State: Terminable {
                    case start, waiting, finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start }
                struct Output { let isWaiting: Bool }
                struct Env {
                    let effectStarted = Expectation()
                    let expectCancelled = Expectation()
                }
                
                static func update(_ state: inout State, event: Event) -> (T.Effect?, Output) {
                    guard state == .start && event == .start else {
                        return (nil, Output(isWaiting: false))
                    }
                    state = .waiting
                    return (longRunningEffect(), Output(isWaiting: true))
                }
                
                static func longRunningEffect() -> T.Effect {
                    T.Effect(operation: { env, _ in
                        do {
                            env.effectStarted.fulfill()
                            try await Task.sleep(for: .seconds(100))
                            #expect(Bool(false), "Effect should have been cancelled")
                        } catch {
                            env.expectCancelled.fulfill()
                            #expect(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
                            throw error
                        }
                    })
                }
            }
            
            let proxy = T.Proxy()
            try proxy.send(.start)
            let env = T.Env()
            
            let task = Task {
                try await T.run(
                    initialState: .start,
                    proxy: proxy,
                    env: env,
                    output: Callback { @MainActor _ in /* output consumed */ }
                )
            }
            
            // Cancel after effect starts
            Task {
                try await env.effectStarted.await(timeout: .seconds(10))
                proxy.cancel()
            }
            
            try await env.expectCancelled.await(timeout: .seconds(10))
            let error = await #expect(throws: TransducerError.self) {
                try await task.value
            }
            #expect(error == .cancelled)
        }
       
        @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
        @MainActor
        @Test
        func cancelIdleEffectTransducerWhenRunningAsynchronousEffects() async throws {
            enum T: EffectTransducer {
                enum State: Terminable {
                    case start, waiting, finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start, ready }
                struct Env {
                    let effectStarted = Expectation()
                    let effectCancelled = Expectation()
                }

                static func update(_ state: inout State, event: Event) -> T.Effect? {
                    guard state == .start && event == .start else { return nil }
                    state = .waiting
                    return makeEffect()
                }

                static func makeEffect() -> T.Effect {
                    T.Effect(operation: { env, input in
                        do {
                            env.effectStarted.fulfill()
                            try await Task.sleep(for: .seconds(100))
                            #expect(Bool(false), "Effect should have been cancelled")
                            try input.send(.ready)
                        } catch {
                            env.effectCancelled.fulfill()
                            #expect(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
                            throw error
                        }
                    })
                }
            }

            let proxy = T.Proxy()
            try proxy.send(.start)
            let env = T.Env()

            let task = Task {
            try await T.run(initialState: .start, proxy: proxy, env: env)
            }

            Task {
                try await env.effectStarted.await(timeout: .seconds(10))
                proxy.cancel()
            }

            try await env.effectCancelled.await(timeout: .seconds(10))
            let error = await #expect(throws: TransducerError.self) {
                try await task.value
            }
            #expect(error == .cancelled)
        }
    }

    @Suite
    struct CancellationViaTaskCancellation {
        
        @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
        @MainActor
        @Test
        func cancelIdleEffectTransducerWhenRunningAsynchronousEffects() async throws {
            enum T: EffectTransducer {
                enum State: Terminable { case start, waiting, idle, finished; var isTerminal: Bool { self == .finished } }
                enum Event { case start, ready }
                struct Env { let started = Expectation(), cancelled = Expectation() }

                static func update(_ state: inout State, event: Event) -> T.Effect? {
                    guard state == .start, event == .start else { return nil }
                    state = .waiting
                    return T.Effect { env, input in
                        env.started.fulfill()
                        do {
                            try await Task.sleep(for: .seconds(100))
                            try input.send(.ready)
                        } catch {
                            env.cancelled.fulfill()
                            throw error
                        }
                    }
                }
            }

            let proxy = T.Proxy(), env = T.Env()
            try proxy.send(.start)
            let task = Task { try await T.run(initialState: .start, proxy: proxy, env: env) }
            try await env.started.await(timeout: .seconds(10))
            task.cancel()
            try await env.cancelled.await(timeout: .seconds(10))
            await #expect(throws: CancellationError.self) { try await task.value }
        }

        @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
        @MainActor
        @Test
        func cancelIdleEffectTransducerWhenRunningAsynchronousEffectsWithOutput() async throws {
            enum T: EffectTransducer {
                enum State: Terminable {
                    case start, waiting, finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start, ready }
                struct Env {
                    let effectStarted = Expectation()
                    let effectCancelled = Expectation()
                }
                typealias Output = Int

                static func update(_ state: inout State, event: Event) -> (T.Effect?, Output) {
                    guard state == .start && event == .start else { return (nil, -1) }
                    state = .waiting
                    return (T.Effect { env, input in
                        do {
                            env.effectStarted.fulfill()
                            try await Task.sleep(for: .seconds(100))
                            try input.send(.ready)
                        } catch {
                            env.effectCancelled.fulfill()
                            #expect(error is CancellationError)
                            throw error
                        }
                        }, 
                    0)
                }
            }            
            let proxy = T.Proxy(), env = T.Env()
            try proxy.send(.start)
            let task = Task { try await T.run(initialState: .start, proxy: proxy, env: env) }
            
            try await env.effectStarted.await(timeout: .seconds(10))
            task.cancel()
            try await env.effectCancelled.await(timeout: .seconds(10))
            await #expect(throws: CancellationError.self) { try await task.value }
        }

        @MainActor
        @Test
        func ensureIdleEffectTransducerWillCancel() async throws {
            enum T: EffectTransducer {
                enum State: Terminable { 
                    case start, idle, finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start }
                struct Env {}

                static func update(_ state: inout State, event: Event) -> Self.Effect? {
                    if state == .start, event == .start { state = .idle }
                    return nil
                }
            }

            let proxy = T.Proxy()
            try proxy.send(.start)
            let task = Task { try await T.run(initialState: .start, proxy: proxy, env: T.Env()) }

            try await Task.sleep(nanoseconds: 100_000_000)
            task.cancel()
            await #expect(throws: CancellationError.self) { try await task.value }
        }

        @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
        @MainActor
        @Test
        func ensureSuspendedEffectTransducerWillCancel() async throws {
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
                    guard state == .start, event == .start else { return nil }
                    state = .idle
                    return T.Effect(action: { env in
                        do {
                            env.effectStarted.fulfill()
                            try await Task.sleep(for: .seconds(100))
                            #expect(Bool(false), "Effect should have been cancelled")
                            return [.ready]
                        } catch {
                            env.effectCancelled.fulfill()
                            #expect(error is CancellationError)
                            throw error
                        }
                    })
                }
            }

            let proxy = T.Proxy(), env = T.Env()
            try proxy.send(.start)
            let task = Task { try await T.run(initialState: .start, proxy: proxy, env: env) }
            
            try await env.effectStarted.await(timeout: .seconds(10))
            task.cancel()
            try await env.effectCancelled.await(timeout: .seconds(10))
            await #expect(throws: CancellationError.self) { try await task.value }
        }
        
        @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
        @MainActor
        @Test
        func ensureIdleEffectTransducerWithRunningEffectWillCancel() async throws {
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
                    guard state == .start && event == .start else { return nil }
                    state = .idle
                    return Effect { env, input in
                        do {
                            env.effectStarted.fulfill()
                            try await Task.sleep(for: .seconds(100))
                            #expect(Bool(false), "Effect should have been cancelled")
                            try input.send(.ready)
                        } catch {
                            #expect(error is CancellationError, "Expected CancellationError, got \(type(of: error))")
                            env.effectCancelled.fulfill()
                            throw error
                        }
                    }
                }
            }

            let proxy = T.Proxy()
            try proxy.send(.start)
            let env = T.Env()

            let task = Task {
                try await T.run(initialState: .start, proxy: proxy, env: env)
            }

            try await env.effectStarted.await(timeout: .seconds(10))
            task.cancel()
            try await env.effectCancelled.await(timeout: .seconds(10))

            await #expect(throws: CancellationError.self) {
                try await task.value
            }
        }

        @MainActor
        @Test
        func ensureIdleEffectTransducerWithOutputWillCancel() async throws {
            enum T: EffectTransducer {
                enum State: Terminable { 
                    case start, idle, finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start }
                struct Env {}
                typealias Output = Int

                static func update(_ state: inout State, event: Event) -> (Self.Effect?, Output) {
                    guard state == .start && event == .start else { return (nil, 0) }
                    state = .idle
                    return (nil, 0)
                }
            }
            let proxy = T.Proxy()
            try proxy.send(.start)
            let task = Task {
                try await T.run(initialState: .start, proxy: proxy, env: T.Env())
            }
            try await Task.sleep(for: .milliseconds(100))
            task.cancel()
            await #expect(throws: CancellationError.self) {
                try await task.value
            }
        }                 
    }  

}
