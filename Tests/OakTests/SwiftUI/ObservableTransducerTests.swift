import Testing
import Oak
import Foundation

#if canImport(Observation)

/**
 * Comprehensive unit tests for `ObservableTransducer` to verify:
 * - Lifecycle management (initialization, termination of the transducer)
 * - Verify no cyclic references exists.
 * - ObservableTransducer deinitialisation cancels transducer.
 * - State observation and updates
 * - Input handling and event propagation
 * - Output subject management
 * - Error handling scenarios
 * - Proxy lifecycle coordination
 *
 */

@Suite struct ObservableTransducerTests {
    
    @Suite struct BasicInitializationTests {
        // MARK: - Test Types
        
        enum VoidTransducer: Transducer {
            enum State: NonTerminal { case start }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) {}
        }
        
        enum OutputTransducer: Transducer {
            enum State: NonTerminal { case start }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) -> Int { 1 }
        }
        
        enum EffectTransducer: Oak.EffectTransducer {
            enum State: NonTerminal { case start }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) -> Self.Effect? { nil }
        }
        
        enum EffectOutputTransducer: Oak.EffectTransducer {
            enum State: NonTerminal { case start }
            enum Event { case start }
            typealias Output = Int
            static func update(_ state: inout State, event: Event) -> (Self.Effect?, Output) { (nil, 1) }
        }
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func createVoidTransducer() async throws {
            typealias T = VoidTransducer
            let observableTransducer = ObservableTransducer<T>(
                initialState: .start,
                proxy: .init(),
                completion: nil,
            )
            
            #expect(T.Output.self == Void.self)
            #expect(ObservableTransducer<T>.Output.self == Void.self)
            #expect(observableTransducer.isRunning == true)
            #expect(observableTransducer.state == .start)
        }
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func createVoidTransducer2() async throws {
            typealias T = VoidTransducer
            let observableTransducer = ObservableTransducer<T>(
                initialState: .start,
            )
            #expect(T.Output.self == Void.self)
            #expect(ObservableTransducer<T>.Output.self == Void.self)
            #expect(observableTransducer.isRunning == true)
            #expect(observableTransducer.state == .start)
        }
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func createVoidTransducer3() async throws {
            typealias T = VoidTransducer
            let observableTransducer = ObservableTransducer(
                of: T.self,
                initialState: .start,
                completion: .init({ result in }),
            )
            #expect(T.Output.self == Void.self)
            #expect(ObservableTransducer<T>.Output.self == Void.self)
            #expect(observableTransducer.isRunning == true)
            #expect(observableTransducer.state == .start)
        }

        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func createOutputTransducer() async throws {
            typealias T = OutputTransducer
            let observableTransducer = ObservableTransducer(
                of: T.self,
                initialState: .start,
                proxy: .init(),
                output: Callback({ output in }),
                completion: nil,
            )
            #expect(T.Output.self == Int.self)
            #expect(ObservableTransducer<T>.Output.self == Int.self)
            #expect(observableTransducer.isRunning == true)
            #expect(observableTransducer.state == .start)
        }
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func createOutputTransducer2() async throws {
            typealias T = OutputTransducer
            let observableTransducer = ObservableTransducer<T>(
                of: T.self,
                initialState: .start,
                output: NoCallback(),
            )
            #expect(T.Output.self == Int.self)
            #expect(ObservableTransducer<T>.Output.self == Int.self)
            #expect(observableTransducer.isRunning == true)
            #expect(observableTransducer.state == .start)
        }
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func createEffectTransducer() async throws {
            typealias T = EffectTransducer
            let observableTransducer = ObservableTransducer(
                of: T.self,
                initialState: .start,
                proxy: .init(),
                env: Void(),
                completion: nil
            )
            #expect(T.Output.self == Void.self)
            #expect(T.Env.self == Void.self)
            #expect(ObservableTransducer<T>.Output.self == Void.self)
            #expect(ObservableTransducer<T>.Env.self == Void.self)
            #expect(observableTransducer.isRunning == true)
            #expect(observableTransducer.state == .start)
        }
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func createEffectTransducer2() async throws {
            typealias T = EffectTransducer
            let observableTransducer = ObservableTransducer<T>(
                initialState: .start,
                env: Void(),
            )
            #expect(T.Output.self == Void.self)
            #expect(T.Env.self == Void.self)
            #expect(ObservableTransducer<T>.Output.self == Void.self)
            #expect(ObservableTransducer<T>.Env.self == Void.self)
            #expect(observableTransducer.isRunning == true)
            #expect(observableTransducer.state == .start)
        }
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func createEffectOutputTransducer() async throws {
            typealias T = EffectOutputTransducer
            typealias Completion = ObservableTransducer<T>.Completion
            let observableTransducer = ObservableTransducer(
                of: EffectOutputTransducer.self,
                initialState: .start,
                proxy: .init(),
                env: Void(),
                output: Callback { output in },
                completion: .init() { result in
                }
            )
            #expect(T.Output.self == Int.self)
            #expect(T.Env.self == Void.self)
            #expect(ObservableTransducer<T>.Output.self == Int.self)
            #expect(ObservableTransducer<T>.Env.self == Void.self)
            #expect(observableTransducer.isRunning == true)
            #expect(observableTransducer.state == .start)
        }
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func createEffectOutputTransducer2() async throws {
            typealias T = EffectOutputTransducer
            let observableTransducer = ObservableTransducer<EffectOutputTransducer>(
                initialState: .start,
                env: Void(),
                output: NoCallback(),
            )
            #expect(T.Output.self == Int.self)
            #expect(T.Env.self == Void.self)
            #expect(ObservableTransducer<T>.Output.self == Int.self)
            #expect(ObservableTransducer<T>.Env.self == Void.self)
            #expect(observableTransducer.isRunning == true)
            #expect(observableTransducer.state == .start)
        }
    }
    
    @Suite struct TerminalCompletionTests {
        // MARK: - Test Types
        
        enum VoidTransducer: Transducer {
            enum State: Terminable { case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) {
                state = .finished
            }
        }
        
        enum OutputTransducer: Transducer {
            enum State: Terminable { case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) -> Int {
                state = .finished
                return 1
            }
        }
        
        enum EffectTransducer: Oak.EffectTransducer {
            enum State: Terminable { case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) -> Self.Effect? {
                state = .finished
                return nil
            }
        }
        
        enum EffectOutputTransducer: Oak.EffectTransducer {
            enum State: Terminable { case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start }
            typealias Output = Int
            static func update(_ state: inout State, event: Event) -> (Self.Effect?, Output) {
                state = .finished
                return (nil, 1)
            }
        }
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func testCompletionCalledWithVoidTransducer() async throws {
            let expectCompletionCalled = Expectation()
            typealias T = VoidTransducer
            typealias Completion = ObservableTransducer<T>.Completion
            let observableTransducer = ObservableTransducer(
                of: T.self,
                initialState: .start,
                proxy:  Proxy(initialEvent: .start), // !! we need to start
                completion: Completion { result in
                    MainActor.shared.assertIsolated()
                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        Issue.record("Unexpected error: \(error)")
                    }
                    expectCompletionCalled.fulfill()
                },
            )
            try await expectCompletionCalled.await(timeout: .seconds(10))
            #expect(observableTransducer.isRunning == false)
            #expect(observableTransducer.state == .finished)
        }
        
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func testCompletionCalledWithOutputTransducer() async throws {
            let expectCompletionCalled = Expectation()
            typealias T = OutputTransducer
            let observableTransducer = ObservableTransducer(
                of: T.self,
                initialState: .start,
                proxy:  Proxy(initialEvent: .start), // !! we need to start
                output: Callback({ output in }),
                completion: .init { result in
                    MainActor.shared.assertIsolated()
                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        Issue.record("Unexpected error: \(error)")
                    }
                    expectCompletionCalled.fulfill()
                },
            )
            try await expectCompletionCalled.await(timeout: .seconds(10))
            #expect(observableTransducer.isRunning == false)
            #expect(observableTransducer.state == .finished)
        }
        
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func testCompletionCalledWithEffectTransducer() async throws {
            let expectCompletionCalled = Expectation()
            typealias T = EffectTransducer
            let observableTransducer = ObservableTransducer(
                of: T.self,
                initialState: .start,
                proxy:  Proxy(initialEvent: .start), // !! we need to start
                env: Void(),
                completion: .init { result in
                    MainActor.shared.assertIsolated()
                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        Issue.record("Unexpected error: \(error)")
                    }
                    expectCompletionCalled.fulfill()
                },
            )
            try await expectCompletionCalled.await(timeout: .seconds(10))
            #expect(observableTransducer.isRunning == false)
            #expect(observableTransducer.state == .finished)
        }
                
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func testCompletionCalledEffectOutputTransducer() async throws {
            let expectCompletionCalled = Expectation()
            typealias T = EffectOutputTransducer
            let observableTransducer = ObservableTransducer(
                of: EffectOutputTransducer.self,
                initialState: .start,
                proxy:  Proxy(initialEvent: .start), // !! we need to start
                env: Void(),
                output: Callback { output in },
                completion: .init { result in
                    MainActor.shared.assertIsolated()
                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        Issue.record("Unexpected error: \(error)")
                    }
                    expectCompletionCalled.fulfill()
                },
            )
            try await expectCompletionCalled.await(timeout: .seconds(10))
            #expect(observableTransducer.isRunning == false)
            #expect(observableTransducer.state == .finished)
        }
    }
    
    @Suite struct CancellationWithProxyTests {
        // There are only a few tests since most of the behaviour is
        // inherited from the transducer which has its own tests.
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func testCancellationWithProxy() async throws {
            // Define a simple transducer for testing cancellation
            // via the proxy.
            //
            // Caution: we cannot cancel a transducer via a proxy
            // when the transducer is suspended in an output function,
            // since the async loop is not processing the cancellation
            // request. Here, we have no suspended output function,
            // and the transducer should receive and process the
            // cancel request.
            enum T: Transducer {
                enum State: NonTerminal, Equatable {
                    case start
                    case running(Int)
                }
                enum Event {
                    case increment
                }
                static func update(_ state: inout State, event: Event) -> Int {
                    switch (state, event) {
                    case (.start, .increment):
                        state = .running(1)
                        return 1
                    case (.running(let count), .increment):
                        let newCount = count + 1
                        state = .running(newCount)
                        return newCount
                    }
                }
            }

            let expectFailure = Expectation()
            
            // Create an ObservableTransducer with the cancellable transducer
            let observableTransducer = ObservableTransducer(
                of: T.self,
                initialState: .start,
                output: NoCallback(),
                completion: .init { result in
                    switch result {
                    case .success:
                        Issue.record("completion handler should not receive a success")
                    case .failure(let error):
                        #expect(error is TransducerError)  // Proxy cancelled.
                        expectFailure.fulfill()
                    }
                },
            )
            
            // Ensure the transducer is running
            #expect(observableTransducer.isRunning == true)
            #expect(observableTransducer.state == .start)
            
            // Send an event to change state
            try observableTransducer.proxy.send(.increment)
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            
            // Use the proxy to cancel the running transducer
            observableTransducer.proxy.cancel()
            try await expectFailure.await(timeout: .seconds(10))

            // Ensure the transducer is not running after cancellation
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            #expect(observableTransducer.isRunning == false)
            
            // Read the state - it should reflect the last processed event
            // Note: The exact state depends on timing, but it should be valid
            switch observableTransducer.state {
            case .start, .running(_):
                break // Both are valid depending on timing
            }
        }
    }
    
    @Suite struct CancellationWhenActorDeinitialisesTests {
        // This requires more and more thoughtful tests. When
        // the host is "dying" under the feet of a transducer,
        // bad things can happen. For example a suspended run
        // function may resume after the host has been deallocated.
        // When the transducer's implementation does not account
        // for this, an access to the state variable can happen.
        // However, the storage is already deallocated. When an
        // `UnownedReferenceKeyPathStorage` is used, it will crash.
        // When a `WeakReferenceKeyPathStorage` is used, it will
        // cause a fatal error.
        
        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func testNonTerminalTransducerShouldCancel() async throws {
            
            // Define a simple transducer for testing deinitialization.
            //
            // This transducer enters the mode `active` and never
            // terminates. It has no effects, and no outputs.
            enum NonTerminalTransducer: Transducer {
                enum State: NonTerminal { case start,active }
                enum Event { case activate }
                static func update(_ state: inout State, event: Event) {
                    switch (state, event) {
                    case (.start, .activate):
                        state = .active
                    case (.active, .activate):
                        break // Stay active
                    }
                }
            }
            typealias T = NonTerminalTransducer

            weak var weakTransducer: ObservableTransducer<T>?
            
            let expectFailure = Expectation()
            
            Task {
                do {
                    // Create an ObservableTransducer and assign it to weak variable
                    let observableTransducer = ObservableTransducer<T>(
                        initialState: .start,
                        completion: .init { result in
                            switch result {
                            case .success:
                                Issue.record("completion handler should not receive a success")
                            case .failure(let error):
                                #expect(error is CancellationError)  // Task cancelled.
                                expectFailure.fulfill()
                            }
                        }
                    )
                    weakTransducer = observableTransducer
                    
                    // Ensure the transducer is running and weak reference exists
                    #expect(observableTransducer.isRunning == true)
                    #expect(weakTransducer != nil)
                    #expect(observableTransducer.state == .start)
                    
                    // Send an event to activate the transducer
                    try? observableTransducer.proxy.send(.activate)
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                // observableTransducer strong reference goes out of scope here
            }

            try await expectFailure.await(timeout: .seconds(10))
            // The weak variable should become nil (actor deallocated)
            #expect(weakTransducer == nil)
        }

        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func testTransducerSuspendedInOutputShouldCancel() async throws {
            
            // Define a simple transducer for testing deinitialization.
            //
            // This transducer is suspended while waiting for an
            // output to be send through the subject. Note, while
            // suspended in output, the transducer cannot receive
            // events. Cancelling the tranducer's task will cause
            // the send function of the subject to throw a
            // `CancellationError`, which also causes the async
            // loop to throw. Any catch handler should not attempt
            // to access the state in any case. Otherwise a crash
            // might happen, because the host does not exist anymore.
            enum SuspendedInOutputTransducer: Oak.Transducer {
                enum State: NonTerminal { case start, active }
                enum Event { case activate, tick }
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> Int {
                    switch (state, event) {
                    case (.start, .activate):
                        return 1
                    case (.active, .activate):
                        return 0
                    case (_, .tick):
                        return 0 // we never reach here
                    }
                }
            }
            
            typealias T = SuspendedInOutputTransducer
            
            weak var weakTransducer: ObservableTransducer<T>?
            
            let expectOutputThrows = Expectation()
            let expectFailure = Expectation()

            Task {
                let expectCallOutput = Expectation()
                do {
                    // Create an ObservableTransducer and assign it to weak variable
                    let observableTransducer = ObservableTransducer<T>.init(
                        initialState: .start,
                        output: Callback { output in
                            switch output {
                            case 1:
                                expectCallOutput.fulfill()
                                let error = await #expect(throws: CancellationError.self) {
                                    try await Task.sleep(nanoseconds: 100_000_000_000)
                                }
                                if let error {
                                    expectOutputThrows.fulfill()
                                    throw error
                                }
                            default:
                                break
                            }
                        },
                        completion: .init { result in
                            switch result {
                            case .success:
                                Issue.record("completion handler should not receive a success")
                            case .failure(let error):
                                #expect(error is CancellationError)  // Task cancelled.
                                expectFailure.fulfill()
                            }
                        }
                    )
                    
                    weakTransducer = observableTransducer
                    
                    // Ensure the transducer is running and weak reference exists
                    #expect(observableTransducer.isRunning == true)
                    #expect(weakTransducer != nil)
                    #expect(observableTransducer.state == .start)
                    
                    // Send an event to activate the transducer
                    try? observableTransducer.proxy.send(.activate)
                    try await expectCallOutput.await(timeout: .seconds(1))
                    _ = observableTransducer
                }
                // observableTransducer strong reference goes out of scope here
            }
            try await expectFailure.await(timeout: .seconds(10))
            try await expectOutputThrows.await(timeout: .seconds(10))
            // Give time for deallocation
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            
            // The weak variable should become nil (actor deallocated)
            #expect(weakTransducer == nil)
        }

        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func testTransducerSuspendedInActionShouldCancel() async throws {
            
            // Define a simple transducer for testing deinitialization.
            //
            // This transducer calls an action which suspends
            // indefinitely. Note, while suspended in an action,
            // the transducer cannot receive events. Cancelling
            // the transducer's task will cause the async action
            // function to throw a `CancellationError`, which also
            // causes the async loop to throw. Any catch handler
            // should not attempt to access the state in any case.
            // Otherwise a crash might happen, because the host
            // does not exist anymore.
            
            enum SuspendedInActionTransducer: EffectTransducer {
                enum State: NonTerminal { case start, active }
                enum Event { case activate, tick }
                struct Env { let expectActionCalled = Expectation() }
                static func update(_ state: inout State, event: Event) -> Self.Effect? {
                    switch (state, event) {
                    case (.start, .activate):
                        return Effect { env, isolated in
                            env.expectActionCalled.fulfill()
                            try await Task.sleep(for: .seconds(100))
                            return .tick
                        }
                    case (.active, .activate):
                        return nil
                    case (_, .tick):
                        return nil // we never reach here
                    }
                }
            }
            
            typealias T = SuspendedInActionTransducer
            
            weak var weakTransducer: ObservableTransducer<T>?
            
            let expectFailure = Expectation()
            let expectCompletionCalled = Expectation()
            let env = T.Env()
            Task {
                do {
                    // Create an ObservableTransducer and assign it to weak variable
                    let observableTransducer = ObservableTransducer<T>.init(
                        initialState: .start,
                        env: env,
                        completion: .init { result in
                            switch result {
                            case .success:
                                Issue.record("completion handler should not receive a success")
                            case .failure(let error):
                                #expect(error is CancellationError)  // Task cancelled.
                                expectFailure.fulfill()
                            }
                            expectCompletionCalled.fulfill()
                        }
                    )
                    
                    weakTransducer = observableTransducer
                    
                    // Ensure the transducer is running and weak reference exists
                    #expect(observableTransducer.isRunning == true)
                    #expect(weakTransducer != nil)
                    #expect(observableTransducer.state == .start)
                    
                    // Send an event to activate the transducer
                    try? observableTransducer.proxy.send(.activate)
                    try await env.expectActionCalled.await(timeout: .seconds(1))
                    _ = observableTransducer
                }
                // observableTransducer strong reference goes out of scope here
            }
            try await expectCompletionCalled.await(timeout: .seconds(10))
            try await expectFailure.await(timeout: .seconds(10))
            // Give time for deallocation
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
            
            // The weak variable should become nil (actor deallocated)
            #expect(weakTransducer == nil)
        }
    }
    
    @Suite struct ObserveStateTests {
        
        // Define a simple transducer for state observation
        enum StateObservationTransducer: Transducer {
            enum State: NonTerminal, Equatable {
                case start
                case step1
                case step2
                case step3
            }
            enum Event {
                case next
            }
            static func update(_ state: inout State, event: Event) {
                switch (state, event) {
                case (.start, .next):
                    state = .step1
                case (.step1, .next):
                    state = .step2
                case (.step2, .next):
                    state = .step3
                case (.step3, .next):
                    break // Stay at step3
                }
            }
        }

        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func testStateObservation() async throws {
            let stateActor = StateActor()
            
            // Create an ObservableTransducer
            let observableTransducer = ObservableTransducer<StateObservationTransducer>(
                initialState: .start
            )
            
            // Ensure the transducer is running
            #expect(observableTransducer.isRunning == true)
            #expect(observableTransducer.state == .start)
            
            // Capture initial state
            await stateActor.addState(observableTransducer.state)
            
            // Send 3 events to the transducer
            try observableTransducer.proxy.send(.next)
            try await Task.sleep(nanoseconds: 10_000_000) // Small delay for processing
            await stateActor.addState(observableTransducer.state)
            
            try observableTransducer.proxy.send(.next)
            try await Task.sleep(nanoseconds: 10_000_000)
            await stateActor.addState(observableTransducer.state)
            
            try observableTransducer.proxy.send(.next)
            try await Task.sleep(nanoseconds: 10_000_000)
            await stateActor.addState(observableTransducer.state)
            
            // Ensure the state changes can be observed and match expectation
            let capturedStates = await stateActor.getStates()
            #expect(capturedStates.count >= 3) // At least initial + some changes
            
            // The final state should be step3
            #expect(observableTransducer.state == .step3)
            
            // Verify progression (timing-dependent, so we check final state)
            #expect(capturedStates.contains(.start))
            #expect(capturedStates.last == .step3)
        }
        
        // Helper actor to capture state changes safely
        actor StateActor {
            private var states: [StateObservationTransducer.State] = []
            
            func addState(_ state: StateObservationTransducer.State) {
                states.append(state)
            }
            
            func getStates() -> [StateObservationTransducer.State] {
                return states
            }
        }
    }
    
    @Suite struct ObserveOutputTests {
        
        // Define a simple transducer that produces output
        enum OutputObservationTransducer: Transducer {
            enum State: NonTerminal, Equatable {
                case start
                case counting(Int)
            }
            enum Event {
                case increment
            }
            static func update(_ state: inout State, event: Event) -> Int {
                switch (state, event) {
                case (.start, .increment):
                    state = .counting(1)
                    return 1
                case (.counting(let count), .increment):
                    let newCount = count + 1
                    state = .counting(newCount)
                    return newCount
                }
            }
        }

        @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
        @MainActor
        @Test func testOutputObservation() async throws {
            let outputActor = OutputActor()
            let expectation = Expectation(minFulfillCount: 3)
            
            // Create output callback
            let outputCallback = Callback<Int> { output in
                Task {
                    await outputActor.addOutput(output)
                    expectation.fulfill()
                }
            }
            
            // Create an ObservableTransducer with output callback
            let observableTransducer = ObservableTransducer<OutputObservationTransducer>(
                initialState: .start,
                output: outputCallback
            )
            
            // Ensure the transducer is running
            #expect(observableTransducer.isRunning == true)
            #expect(observableTransducer.state == .start)
            
            // Send 3 events to the transducer
            try observableTransducer.proxy.send(.increment)
            try observableTransducer.proxy.send(.increment)
            try observableTransducer.proxy.send(.increment)
            
            // Wait for outputs to be captured
            try await expectation.await(timeout: .seconds(1))
            
            // Capture the outputs and verify they match expectation
            let capturedOutputs = await outputActor.getOutputs()
            #expect(capturedOutputs.count == 3)
            #expect(capturedOutputs == [1, 2, 3])
            
            // Verify final state
            #expect(observableTransducer.state == .counting(3))
        }
        
        // Helper actor to capture outputs safely
        actor OutputActor {
            private var outputs: [Int] = []
            
            func addOutput(_ output: Int) {
                outputs.append(output)
            }
            
            func getOutputs() -> [Int] {
                return outputs
            }
        }
    }
}


#else    
@MainActor
struct ObservableTransducerTestsFallback {   
    @Test
    func notAvailableObervationFramework() async throws {
        #expect(Bool(false), "ObservableTransducer tests requires the Observation framwork. Run from Xcode with a run destination which can import Observation to execute full ObservableTransducer test suite. This skip is expected when testing from command line.")
    }
}
#endif
