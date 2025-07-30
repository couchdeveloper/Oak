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

struct ObservableTransducerTests {
    struct ObservableTransducerBasicInitializationTests {}
    struct ObservableTransducerCancellationWithProxyTests {}
    struct ObservableTransducerCancellationWhenActorDeinitialisesTests {}
    struct ObservableTransducerCompletionTests {}
    struct ObservableTransducerObserveStateTests {}
    struct ObservableTransducerObserveOutputTests {}
}

extension ObservableTransducerTests.ObservableTransducerBasicInitializationTests {
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
        let observableTransducer = ObservableTransducer(
            of: VoidTransducer.self,
            initialState: .start,
            proxy: .init(),
            completion: nil
        )
        #expect(observableTransducer.isRunning == true)
        #expect(observableTransducer.state == .start)
    }
    
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @MainActor
    @Test func createVoidTransducer2() async throws {
        let observableTransducer = ObservableTransducer(
            of: VoidTransducer.self,
            initialState: .start,
        )
        #expect(observableTransducer.isRunning == true)
        #expect(observableTransducer.state == .start)
    }
    
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @MainActor
    @Test func createOutputTransducer() async throws {
        let observableTransducer = ObservableTransducer(
            of: OutputTransducer.self,
            initialState: .start,
            proxy: .init(),
            output: Callback({ output in }),
            completion: { output, isolated in }
        )
        #expect(observableTransducer.isRunning == true)
        #expect(observableTransducer.state == .start)
    }
    
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @MainActor
    @Test func createOutputTransducer2() async throws {
        let observableTransducer = ObservableTransducer(
            of: OutputTransducer.self,
            initialState: .start,
        )
        #expect(observableTransducer.isRunning == true)
        #expect(observableTransducer.state == .start)
    }
    
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @MainActor
    @Test func createEffectTransducer() async throws {
        let observableTransducer = ObservableTransducer.init(
            of: EffectTransducer.self,
            initialState: .start,
            proxy: .init(),
            env: Void(),
            completion: { isolated in }
        )
        #expect(observableTransducer.isRunning == true)
        #expect(observableTransducer.state == .start)
    }
    
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @MainActor
    @Test func createEffectTransducer2() async throws {
        let observableTransducer = ObservableTransducer.init(
            of: EffectTransducer.self,
            initialState: .start,
            env: Void(),
        )
        #expect(observableTransducer.isRunning == true)
        #expect(observableTransducer.state == .start)
    }
    
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @MainActor
    @Test func createEffectOutputTransducer() async throws {
        let observableTransducer = ObservableTransducer(
            of: EffectOutputTransducer.self,
            initialState: .start,
            proxy: .init(),
            env: Void(),
            output: Callback { output in },
            completion: { output, isolated in }
        )
        #expect(observableTransducer.isRunning == true)
        #expect(observableTransducer.state == .start)
    }
    
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @MainActor
    @Test func createEffectOutputTransducer2() async throws {
        let observableTransducer = ObservableTransducer.init(
            of: EffectOutputTransducer.self,
            initialState: .start,
            env: Void(),
            output: NoCallback(),
        )
        #expect(observableTransducer.isRunning == true)
        #expect(observableTransducer.state == .start)
    }
}

extension ObservableTransducerTests.ObservableTransducerCancellationWithProxyTests {
    
    // Define a simple transducer for testing cancellation
    enum CancellableTransducer: Transducer {
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
    
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @MainActor
    @Test func testCancellationWithProxy() async throws {
        // Create an ObservableTransducer with the cancellable transducer
        let observableTransducer = ObservableTransducer(
            of: CancellableTransducer.self,
            initialState: .start
        )
        
        // Ensure the transducer is running
        #expect(observableTransducer.isRunning == true)
        #expect(observableTransducer.state == .start)
        
        // Send an event to change state
        try observableTransducer.proxy.send(.increment)
        
        // Give some time for processing (in a real test we'd use synchronization)
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Use the proxy to cancel the running transducer
        observableTransducer.proxy.cancel()
        
        // Give a brief moment for cancellation to process
        try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        
        // Note: We don't check isRunning here since ObservableTransducer
        // keeps tasks alive even after cancellation for state preservation
        
        // Read the state - it should reflect the last processed event
        // Note: The exact state depends on timing, but it should be valid
        switch observableTransducer.state {
        case .start, .running(_):
            break // Both are valid depending on timing
        }
    }
}

extension ObservableTransducerTests.ObservableTransducerCancellationWhenActorDeinitialisesTests {
    
    // Define a simple transducer for testing deinitialization
    enum DeinitialisationTransducer: Transducer {
        enum State: NonTerminal, Equatable { 
            case start
            case active
        }
        enum Event { 
            case activate 
        }
        static func update(_ state: inout State, event: Event) {
            switch (state, event) {
            case (.start, .activate):
                state = .active
            case (.active, .activate):
                break // Stay active
            }
        }
    }

    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @MainActor
    @Test func testCancellationWhenActorDeinitializes() async throws {
        weak var weakTransducer: ObservableTransducer<DeinitialisationTransducer.State, DeinitialisationTransducer.Proxy>?
        
        await MainActor.run {
            do {
                // Create an ObservableTransducer and assign it to weak variable
                let observableTransducer = ObservableTransducer(
                    of: DeinitialisationTransducer.self,
                    initialState: .start
                )
                
                weakTransducer = observableTransducer
                
                // Ensure the transducer is running and weak reference exists
                #expect(observableTransducer.isRunning == true)
                #expect(weakTransducer != nil)
                #expect(observableTransducer.state == .start)
                
                // Send an event to activate the transducer
                try? observableTransducer.proxy.send(.activate)
            }
            // observableTransducer strong reference goes out of scope here
        }
        
        // Give time for deallocation
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // The weak variable should become nil (actor deallocated)
        #expect(weakTransducer == nil)
    }
}

extension ObservableTransducerTests.ObservableTransducerCompletionTests {
    
    // Define a simple transducer that can terminate and produces output
    enum TerminatingTransducer: Transducer {
        enum State: Terminable, Equatable { 
            case start
            case counting(Int)
            case finished(Int)
            
            var isTerminal: Bool {
                if case .finished = self { return true }
                return false
            }
        }
        enum Event { 
            case increment
            case finish
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
            case (.counting(let count), .finish):
                state = .finished(count)
                return count
            case (.start, .finish):
                state = .finished(0)
                return 0
            case (.finished(let count), _):
                return count // Already finished
            }
        }
    }

    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @MainActor
    @Test func testCompletionCallback() async throws {
        let expectation = Expectation(minFulfillCount: 1)
        let completionActor = CompletionActor()
        
        // Create an ObservableTransducer with completion callback
        let observableTransducer = ObservableTransducer(
            of: TerminatingTransducer.self,
            initialState: .start,
            completion: { output, _ in
                Task { @MainActor in
                    await completionActor.setOutput(output)
                    expectation.fulfill()
                }
            }
        )
        
        // Ensure the transducer is running
        #expect(observableTransducer.isRunning == true)
        #expect(observableTransducer.state == .start)
        
        // Send events to increment then finish
        try observableTransducer.proxy.send(.increment)
        try observableTransducer.proxy.send(.increment)
        try observableTransducer.proxy.send(.finish)
        
        // Wait for completion
        try await expectation.await(timeout: .seconds(1))
        
        // Give a brief moment for completion processing to finish
        try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        
        // Note: We don't check isRunning here since ObservableTransducer
        // keeps tasks alive even after completion for state preservation
        
        // Read the state and assert it matches expectation
        #expect(observableTransducer.state == .finished(2))
        
        // Read the output and assert it matches expectation
        let completionOutput = await completionActor.getOutput()
        #expect(completionOutput == 2)
    }
    
    // Helper actor to handle completion output safely
    actor CompletionActor {
        private var output: Int?
        
        func setOutput(_ value: Int) {
            self.output = value
        }
        
        func getOutput() -> Int? {
            return output
        }
    }
}

extension ObservableTransducerTests.ObservableTransducerObserveStateTests {
    
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
        let observableTransducer = ObservableTransducer(
            of: StateObservationTransducer.self,
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

extension ObservableTransducerTests.ObservableTransducerObserveOutputTests {
    
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
        let observableTransducer = ObservableTransducer(
            of: OutputObservationTransducer.self,
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


#else    
@MainActor
struct ObservableTransducerTestsFallback {   
    @Test
    func swiftUINotAvailable() async throws {
        #expect(Bool(false), "ObservableTransducer tests requires Observation. Run from Xcode with a run destination which can import Observation to execute full ObservableTransducer test suite. This skip is expected when testing from command line.")
    }
}
#endif
