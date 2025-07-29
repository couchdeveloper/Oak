#if canImport(SwiftUI) && canImport(UIKit)
import Testing
import SwiftUI
import UIKit
import Oak


/**
 * Comprehensive unit tests for TransducerView to verify:
 * - Lifecycle management (initialization, termination)
 * - State binding and updates
 * - Input handling and event propagation
 * - Output subject management
 * - Error handling scenarios
 * - Proxy lifecycle coordination
 *
 * Testing Strategy:
 * SwiftUI views cannot be tested in isolation as they lack the necessary environment
 * and lifecycle. Therefore, we wrap each TransducerView in a UIHostingController
 * following conventional wisdom for testing UIViewController functional parts.
 * This provides the proper SwiftUI hosting environment for realistic testing.
 */
@MainActor
struct TransducerViewTests {
    
    func waitUntilViewAppeared(window: UIWindow) async {
        guard let viewController = window.rootViewController else {
            Issue.record("The window has not root view controller")
            return
        }
        await withCheckedContinuation { continuation in
            CATransaction.begin()
            CATransaction.setCompletionBlock({
                continuation.resume()
            })
            let _ = viewController.view
            if let transitionCoordinator = viewController.transitionCoordinator {
                transitionCoordinator.animate(alongsideTransition: nil) { _ in
                    CATransaction.commit()
                }
            } else {
                CATransaction.commit()
            }
        }
    }


    // MARK: - Test Helpers
    
    /// Helper function to properly host a SwiftUI view for testing
    func hostView<V: View>(_ view: V) async -> (UIHostingController<V>, UIWindow) {
        let hostingController = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        
        // // Allow view to load and render.
        // // Note: we need to dispatch to the main thread in order to allow
        // // the window to render. The 2 ms for waiting comes from the assumption
        // // that the screen will be updated at least every 1/60 second, and 2 ms
        // // should be enough to have executed the render cycle.
        // try? await Task.sleep(nanoseconds: 2_000_000) // 2 ms
        
        return (hostingController, window)
    }
    
    func cleanupView(_ window: UIWindow) {
        window.isHidden = true
    }
    
    // MARK: - Lifecycle Management Tests
    
    @Test
    func bodyRunsOnceOnFirstRender() async throws {

        enum Output {
            case none
            case started
        }
                
        enum TestTransducer: Transducer {
            enum State: NonTerminal {
                case start, idle
            }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) -> Output {
                Issue.record("Unexpected update execution")
                if state == .start && event == .start {
                    state = .idle
                    return .started
                }
                return .none
            }
        }

        var bodyExecutionCount = 0
        let proxy = TestTransducer.Proxy()
        
        let view = TransducerView(
            of: TestTransducer.self,
            initialState: .start,
            proxy: proxy,
            output: Callback { @MainActor output in
                Issue.record("Unexpected callback execution")
            }
        ) { state, input in
            bodyExecutionCount += 1
            return Text("Test - Body executed \(bodyExecutionCount) times")
        }
        
        // Wrap in UIHostingController to provide SwiftUI environment
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        // Verify that the view's body was executed
        #expect(bodyExecutionCount == 1, "Body should be executed once and only once when view is rendered")
        
        // Clean up
        cleanupView(window)
    }
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func updateFunctionExecutesOnEventSendFromProxy() async throws {

        enum Output {
            case none
            case started
        }
                
        enum TestTransducer: Transducer {
            enum State: NonTerminal {
                case start, idle
            }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) -> Output {
                if state == .start && event == .start {
                    state = .idle
                    return .started
                }
                return .none
            }
        }

        let receivedStartedEvent = Expectation()
        var isTransducerStarted = false
        var bodyExecutionCount = 0
        
        let proxy = TestTransducer.Proxy()
        
        let view = TransducerView(
            of: TestTransducer.self,
            initialState: .start,
            proxy: proxy,
            output: Callback { @MainActor output in
                switch output {
                case .none:
                    break
                case .started:
                    isTransducerStarted = true
                    receivedStartedEvent.fulfill()
                }
            }
        ) { state, input in
            bodyExecutionCount += 1
            return Text("Test - Body executed \(bodyExecutionCount) times")
        }
        
        // Wrap in UIHostingController to provide SwiftUI environment
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        // Now send an event to trigger the update function (using proxy):
        try proxy.send(.start)
        
        try await receivedStartedEvent.await(timeout: .seconds(10))

        // Verify that the view's body was executed
        #expect(bodyExecutionCount == 2, "Body should be executed twice")
        #expect(isTransducerStarted)
    }
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func updateFunctionExecutesOnEventSendFromInput() async throws {

        enum Output {
            case none
            case started
        }
                
        enum TestTransducer: Transducer {
            enum State: NonTerminal {
                case start, idle
            }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) -> Output {
                if state == .start && event == .start {
                    state = .idle
                    return .started
                }
                return .none
            }
        }

        var isOutputValueSent = false
        var bodyExecutionCount = 0
        
        let proxy = TestTransducer.Proxy()
        var capturedInput: TestTransducer.Input? = nil
        
        let expectation = Expectation()
        
        let view = TransducerView(
            of: TestTransducer.self,
            initialState: .start,
            proxy: proxy,
            output: Callback { @MainActor output in
                switch output {
                case .none:
                    break
                case .started:
                    isOutputValueSent = true
                    expectation.fulfill()
                }
            }
        ) { state, input in
            bodyExecutionCount += 1
            capturedInput = input
            return Text("Test - Body executed \(bodyExecutionCount) times")
        }
        
        // Wrap in UIHostingController to provide SwiftUI environment
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)

        // Verify that the view's body was executed
        #expect(bodyExecutionCount == 1, "Body should be executed once and only once when view is rendered")
        
        // verify we have captured the input:
        #expect(capturedInput != nil)

        // Now send an event to trigger the update function first time (using input):
        try capturedInput?.send(.start)
        try await expectation.await(timeout: .seconds(10))
        #expect(isOutputValueSent)
        
        // Clean up
        cleanupView(window)
    }
    
    // MARK: - State Management Tests
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func stateUpdatesReflectInView() async throws {
        enum CounterTransducer: Transducer {
            enum State: NonTerminal {
                case count(Int)
                init() { self = .count(0) }
                var value: Int {
                    if case .count(let v) = self { return v }
                    return 0
                }
            }
            enum Event { case increment }
            static func update(_ state: inout State, event: Event) {
                if case .count(let current) = state {
                    state = .count(current + 1)
                }
            }
        }
        
        let proxy = CounterTransducer.Proxy()
        var capturedState: CounterTransducer.State?
        var capturedInput: CounterTransducer.Proxy.Input?
        let expectation = Expectation()

        let view = TransducerView(
            of: CounterTransducer.self,
            initialState: .count(0),
            proxy: proxy
        ) { state, input in
            capturedState = state
            if state.value == 1 {
                expectation.fulfill()
            }
            capturedInput = input
            return Text("\(state.value)")
        }
        
        // Host the view properly
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)

        // Verify initial state capture
        #expect(capturedState?.value == 0)
        #expect(capturedInput != nil)
                
        // Send event and verify state update
        try capturedInput?.send(.increment)
        try await expectation.await(timeout: .seconds(10))
        #expect(capturedState?.value == 1)
        
        // Clean up
        cleanupView(window)
    }
    
    @Test
    func initialStateIsPreserved() async throws {
        enum TestTransducer: Transducer {
            enum State: NonTerminal {
                case custom(String)
                init() { self = .custom("default") }
            }
            enum Event { case dummy }
            static func update(_ state: inout State, event: Event) {}
        }
        
        let customInitialState = TestTransducer.State.custom("custom")
        var capturedState: TestTransducer.State?
        
        let view = TransducerView(
            of: TestTransducer.self,
            initialState: customInitialState,
            proxy: TestTransducer.Proxy()
        ) { state, input in
            capturedState = state
            return Text("Test")
        }
        
        // Host the view properly
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)

        if case .custom(let value) = capturedState {
            #expect(value == "custom")
        } else {
            Issue.record("Expected custom state")
        }
        
        // Clean up
        cleanupView(window)
    }
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func stateChangesTriggersViewUpdate() async throws {
        enum ToggleTransducer: Transducer {
            enum State: NonTerminal {
                case off, on
                init() { self = .off }
            }
            enum Event { case toggle }
            static func update(_ state: inout State, event: Event) {
                switch state {
                case .off: state = .on
                case .on: state = .off
                }
            }
        }
        
        let proxy = ToggleTransducer.Proxy()
        var viewUpdateCount = 0
        let expectation = Expectation()
        
        let view = TransducerView(
            of: ToggleTransducer.self,
            initialState: .off,
            proxy: proxy
        ) { state, input in
            viewUpdateCount += 1
            if case .on = state {
                expectation.fulfill()
            }
            return Text(state == .on ? "ON" : "OFF")
        }
        
        // Host the view properly for initial render
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        let initialCount = viewUpdateCount
        
        try proxy.input.send(.toggle)
        try await expectation.await(timeout: .seconds(10))
        #expect(viewUpdateCount > initialCount)
        
        // Clean up
        cleanupView(window)
    }
    
    // MARK: - Input Handling Tests
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func inputEventsReachTransducer() async throws {
        enum Output {
            case receivedEvent(String)
        }
        
        enum EventTransducer: Transducer {
            enum State: NonTerminal {
                case idle
                init() { self = .idle }
            }
            enum Event { case test(String) }
            static func update(_ state: inout State, event: Event) -> Output {
                if case .test(let message) = event {
                    return .receivedEvent(message)
                }
                return .receivedEvent("")
            }
        }
        
        let expectedCount = 10
        var receivedEvents: [String] = []
        
        let proxy = EventTransducer.Proxy(bufferSize: expectedCount + 2)
        var capturedInput: EventTransducer.Proxy.Input?
        let expectation = Expectation(minFulfillCount: expectedCount)
        
        
        let view = TransducerView(
            of: EventTransducer.self,
            initialState: .idle,
            proxy: proxy,
            output: Callback { @MainActor output in
                if case .receivedEvent(let message) = output, !message.isEmpty {
                    receivedEvents.append(message)
                    print("received output: \(message)")
                    expectation.fulfill()
                }
            }
        ) { state, input in
            capturedInput = input
            return Text("Test")
        }
        
        // Host the view properly
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        // Note:
        // When using the default Proxy type, aka `Oak.Proxy<Event>` as it is
        // defined in the protocol `BaseTransducer`, the proxy will
        // asynchronously send events to the system by using an event buffer.
        // Now, Input is a local type of proxy and it is based on the same
        // event delivery mechanism as its host type `Proxy`.
        // Sending events this way, either through the proxy or through the
        // proxy's Input type will enqueue them into the event buffer before
        // being consumed by the transducer. The size of the event buffer can
        // be set in the initialiser of the proxy. The default size is 8.
        // For the test, the event buffer has been set to 10. Thus, it is
        // expected that the test will succeed.
        #expect(capturedInput != nil)
        for i in 0..<10 {
            #expect(throws: Never.self) {
                try capturedInput?.send(.test("\(i)"))
            }
        }

        try await expectation.await(nanoseconds: 100_000_000)
        // Clean up
        cleanupView(window)

        let accepted = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        #expect(receivedEvents == accepted)
    }
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func inputEventsReachTransducerUsingAsyncProxy() async throws {
        enum Output {
            case receivedEvent(String)
        }
        
        enum EventTransducer: Transducer {
            enum State: NonTerminal {
                case idle
                init() { self = .idle }
            }
            enum Event { case test(String) }
            static func update(_ state: inout State, event: Event) -> Output {
                if case .test(let message) = event {
                    return .receivedEvent(message)
                }
                return .receivedEvent("")
            }
            
            typealias Proxy = Oak.AsyncProxy<Event>
        }
        
        var receivedEvents: [String] = []
        
        let proxy = EventTransducer.Proxy()
        var capturedInput: EventTransducer.Proxy.Input?
        let expectation = Expectation(minFulfillCount: 10)
        
        let view = TransducerView(
            of: EventTransducer.self,
            initialState: .idle,
            proxy: proxy,
            output: Callback { @MainActor output in
                if case .receivedEvent(let message) = output, !message.isEmpty {
                    receivedEvents.append(message)
                    expectation.fulfill()
                    print("output: \(message)")
                }
            }
        ) { state, input in
            capturedInput = input
            return Text("Test")
        }
        
        // Host the view properly
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)

        // Note:
        // When explicitly defining the Proxy type `Oak.AsyncProxy<Event>`
        // in the `EventTransducer`, we are using an `AsyncProxy` for sending
        // events into the system. This event delivery mechansism uses an async
        // function to deliver the event that suspends until after the event
        // has been processed. This also includes being suspended until the
        // delivery of an output value (through a Subject) has been completed.
        // Thus, sending an event will never fail, but it may be delayed as
        // needed.
        // The processing speed of the transducer will be dynamically adjusted
        // so that it is synchronised with its event producers and its output
        // consumers through utilising suspension.
        
        // Here, we are using a suspending loop, which sends events
        // "as fast as it can":
        for i in 0..<10 {
            await capturedInput?.send(.test("\(i)"))
            await Task.yield() // give the output a chance to consume the value
        }
        // after we reach here, we can observe that the new state has been
        // actually computed.
        
        try await expectation.await(nanoseconds: 10_000_000_000)
        let accepted = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        #expect(receivedEvents == accepted)
        
        // Clean up
        cleanupView(window)
    }
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func multipleEventsProcessedInOrder() async throws {
        enum Output {
            case receivedNumber(Int)
        }
        
        enum SequenceTransducer: Transducer {
            enum State: NonTerminal {
                case idle
                init() { self = .idle }
            }
            enum Event { case number(Int) }
            static func update(_ state: inout State, event: Event) -> Output {
                if case .number(let num) = event {
                    return .receivedNumber(num)
                }
                return .receivedNumber(0)
            }
        }
        
        var receivedEvents: [Int] = []
        
        let proxy = SequenceTransducer.Proxy(bufferSize: 100)
        var capturedInput: SequenceTransducer.Proxy.Input?
        let expectation = Expectation()
        
        let view = TransducerView(
            of: SequenceTransducer.self,
            initialState: .idle,
            proxy: proxy,
            output: Callback { @MainActor output in
                if case .receivedNumber(let num) = output, num != 0 {
                    receivedEvents.append(num)
                    if receivedEvents.count == 9 {
                        expectation.fulfill()
                    }
                }
            }
        ) { state, input in
            capturedInput = input
            return Text("Test")
        }
        
        // Host the view properly
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)

        #expect(capturedInput != nil)
        guard let capturedInput else { return }
        // Send multiple events
        // Caution: sending multiple events where the proxy is type `Proxy`
        // can cause the event buffer to overflow!
        for i in 1..<10 {
            try capturedInput.send(.number(i))
            // await Task.yield()  // Yield here to give the output a chance to send events.
        }
        await Task.yield()
        
        try await expectation.await(timeout: .seconds(10))
        #expect(receivedEvents == [1, 2, 3, 4, 5, 6, 7, 8, 9])
        
        // Clean up
        cleanupView(window)
    }
    
    // MARK: - Output Subject Tests
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func outputsSentToSubject() async throws {
        enum OutputTransducer: Transducer {
            enum State: NonTerminal {
                case idle
                init() { self = .idle }
            }
            enum Event { case produce(Int) }
            typealias Output = Int
            
            static func update(_ state: inout State, event: Event) -> Int {
                if case .produce(let value) = event {
                    return value
                }
                return 0
            }
        }
        
        var receivedOutput: Int = 0
        let proxy = OutputTransducer.Proxy()
        var capturedInput: OutputTransducer.Proxy.Input?
        let expectation = Expectation()
        
        let view = TransducerView(
            of: OutputTransducer.self,
            initialState: .idle,
            proxy: proxy,
            output: Callback { @MainActor in
                receivedOutput = $0
                expectation.fulfill()
            }
        ) { state, input in
            capturedInput = input
            return Text("\(receivedOutput)")
        }
        
        // Host the view properly
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)

        #expect(capturedInput != nil)

        try capturedInput?.send(.produce(42))
        try await expectation.await(timeout: .seconds(10))
        #expect(receivedOutput == 42)
        
        // Clean up
        cleanupView(window)
    }
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func initialOutputSent() async throws {
        var receivedOutput: String = ""
        
        enum TestTransducer: Transducer {
            enum State: NonTerminal {
                case idle
                init() { self = .idle }
            }
            enum Event { case dummy }
            typealias Output = String
            static func update(_ state: inout State, event: Event) -> String {
                Issue.record("Unexpected update execution")
                return ""
            }
            
            static func initialOutput(initialState: State) -> Output? {
                "initial"
            }
        }
        
        let expectation = Expectation()
        
        let view = TransducerView(
            of: TestTransducer.self,
            initialState: .idle,
            proxy: TestTransducer.Proxy(),
            output: Callback { @MainActor in
                receivedOutput = $0
                if $0 == "initial" {
                    expectation.fulfill()
                }
            }
        ) { state, input in
            Text("Test")
        }
        
        // Host the view properly
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        try await expectation.await(timeout: .seconds(10))
        #expect(receivedOutput == "initial")
        
        // Clean up
        cleanupView(window)
    }
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func multipleOutputsDelivered() async throws {
        var outputs: [String] = []
        
        enum MultiOutputTransducer: Transducer {
            enum State: NonTerminal {
                case idle
                init() { self = .idle }
            }
            enum Event { case emit(String) }
            typealias Output = String
            
            static func update(_ state: inout State, event: Event) -> String {
                if case .emit(let value) = event {
                    return value
                }
                return ""
            }
        }
        
        let proxy = MultiOutputTransducer.Proxy()
        var capturedInput: MultiOutputTransducer.Proxy.Input?
        let expectation = Expectation()
        
        let view = TransducerView(
            of: MultiOutputTransducer.self,
            initialState: .idle,
            proxy: proxy,
            output: Callback { @MainActor in
                outputs.append($0)
                if $0 == "second" {
                    expectation.fulfill()
                }
            }
        ) { state, input in
            capturedInput = input
            return Text("Test")
        }
        
        // Host the view properly
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        
        try capturedInput?.send(.emit("first"))
        try capturedInput?.send(.emit("second"))
        try await expectation.await(timeout: .seconds(10))
        
        #expect(outputs.contains("first"))
        #expect(outputs.contains("second"))
        
        // Clean up
        cleanupView(window)
    }
    
    // MARK: - Completion Callback Tests
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func completionCallbackInvokedOnSuccess() async throws {
        enum CompletionTransducer: Transducer {
            enum State: NonTerminal {
                case ready, finished
                init() { self = .ready }
            }
            enum Event { case finish }
            typealias Output = String
            
            static func update(_ state: inout State, event: Event) -> String {
                switch (state, event) {
                case (.ready, .finish):
                    state = .finished
                    return "completed"
                default:
                    return ""
                }
            }
        }
        
        var completionCalled = false
        var completionValue: String?
        let completionExpectation = Expectation()
        let outputExpectation = Expectation()
        
        let proxy = CompletionTransducer.Proxy()
        var capturedInput: CompletionTransducer.Proxy.Input?
        
        let view = TransducerView(
            of: CompletionTransducer.self,
            initialState: .ready,
            proxy: proxy,
            output: Callback { @MainActor output in
                if output == "completed" {
                    outputExpectation.fulfill()
                }
            },
            completion: { @MainActor output in
                completionCalled = true
                completionValue = output
                completionExpectation.fulfill()
            }
        ) { state, input in
            capturedInput = input
            return Text("State: \(state)")
        }
        
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        // Trigger completion
        try capturedInput?.send(.finish)
        
        try await outputExpectation.await(timeout: .seconds(10))
        try await completionExpectation.await(timeout: .seconds(10))
        
        #expect(completionCalled)
        #expect(completionValue == "completed")
        
        cleanupView(window)
    }
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func completionCallbackNotInvokedOnError() async throws {
        enum ErrorTransducer: Transducer {
            enum State: NonTerminal {
                case ready
                init() { self = .ready }
            }
            enum Event { case triggerError }
            typealias Output = String
            
            static func update(_ state: inout State, event: Event) throws -> String {
                throw TransducerError.terminated
            }
        }
        
        var completionCalled = false
        let notCalledExpectation = Expectation()
        
        let proxy = ErrorTransducer.Proxy()
        var capturedInput: ErrorTransducer.Proxy.Input?
        
        let view = TransducerView(
            of: ErrorTransducer.self,
            initialState: .ready,
            proxy: proxy,
            completion: { @MainActor output in
                completionCalled = true
                notCalledExpectation.fulfill()
            }
        ) { state, input in
            capturedInput = input
            return Text("Test")
        }
        
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        // Trigger error
        try capturedInput?.send(.triggerError)
        
        // Wait a bit to ensure completion wouldn't be called
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        #expect(!completionCalled)
        
        cleanupView(window)
    }
    
    // MARK: - Optional Proxy Tests
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func transducerViewWorksWithNilProxy() async throws {
        enum SimpleTransducer: Transducer {
            enum State: NonTerminal {
                case idle
                init() { self = .idle }
            }
            enum Event { case test }
            typealias Output = String
            
            static func update(_ state: inout State, event: Event) -> String {
                return "event_received"
            }
        }
        
        var receivedOutput: String?
        let expectation = Expectation()
        var capturedInput: SimpleTransducer.Proxy.Input?
        
        // Test with nil proxy (should create default)
        let view = TransducerView(
            of: SimpleTransducer.self,
            initialState: .idle,
            proxy: nil, // Explicitly nil
            output: Callback { @MainActor output in
                receivedOutput = output
                expectation.fulfill()
            }
        ) { state, input in
            capturedInput = input
            return Text("Test")
        }
        
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        #expect(capturedInput != nil)
        try capturedInput?.send(.test)
        
        try await expectation.await(timeout: .seconds(10))
        #expect(receivedOutput == "event_received")
        
        cleanupView(window)
    }
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func transducerViewWorksWithOmittedProxy() async throws {
        enum SimpleTransducer: Transducer {
            enum State: NonTerminal {
                case idle
                init() { self = .idle }
            }
            enum Event { case test }
            typealias Output = String
            
            static func update(_ state: inout State, event: Event) -> String {
                return "event_received"
            }
        }
        
        var receivedOutput: String?
        let expectation = Expectation()
        var capturedInput: SimpleTransducer.Proxy.Input?
        
        // Test with omitted proxy parameter (should use default)
        let view = TransducerView(
            of: SimpleTransducer.self,
            initialState: .idle,
            output: Callback { @MainActor output in
                receivedOutput = output
                expectation.fulfill()
            }
        ) { state, input in
            capturedInput = input
            return Text("Test")
        }
        
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        #expect(capturedInput != nil)
        try capturedInput?.send(.test)
        
        try await expectation.await(timeout: .seconds(10))
        #expect(receivedOutput == "event_received")
        
        cleanupView(window)
    }
    
    // MARK: - Proxy Change and State Reset Tests
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func proxyChangeRestartsTransducerAndResetsState() async throws {
        enum CounterTransducer: Transducer {
            enum State: NonTerminal, Equatable {
                case count(Int)
                init() { self = .count(0) }
                var value: Int {
                    if case .count(let v) = self { return v }
                    return 0
                }
            }
            enum Event { case increment }
            typealias Output = Int
            
            static func update(_ state: inout State, event: Event) -> Int {
                switch (state, event) {
                case (.count(let current), .increment):
                    state = .count(current + 1)
                    return state.value
                }
            }
            
            static func initialOutput(initialState: State) -> Int? {
                initialState.value
            }
        }
        
        let initialState = CounterTransducer.State.count(5) // Start with 5
        
        var observedStates: [CounterTransducer.State] = []
        var outputs: [Int] = []
        var capturedInput: CounterTransducer.Proxy.Input?
        
        let initialOutputExpectation = Expectation()
        let incrementExpectation = Expectation()
        let proxyChangeExpectation = Expectation()
        
        @State var currentProxy = CounterTransducer.Proxy()
        
        let view = TransducerView(
            of: CounterTransducer.self,
            initialState: initialState,
            proxy: currentProxy,
            output: Callback { @MainActor output in
                outputs.append(output)
                switch outputs.count {
                case 1:
                    initialOutputExpectation.fulfill()
                case 2:
                    incrementExpectation.fulfill()
                case 3:
                    proxyChangeExpectation.fulfill()
                default:
                    break
                }
            }
        ) { state, input in
            observedStates.append(state)
            capturedInput = input
            return VStack {
                Text("Count: \(state.value)")
                Button("Change Proxy") {
                    currentProxy = CounterTransducer.Proxy()
                }
            }
        }
        
        let (hostingController, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        // Wait for initial output
        try await initialOutputExpectation.await(timeout: .seconds(10))
        #expect(outputs == [5]) // Initial state value
        #expect(observedStates.last?.value == 5)
        
        // Increment counter
        try capturedInput?.send(.increment)
        try await incrementExpectation.await(timeout: .seconds(10))
        #expect(outputs == [5, 6])
        #expect(observedStates.last?.value == 6)
        
        // Change proxy - this should restart transducer and reset state
        currentProxy = CounterTransducer.Proxy()
        hostingController.rootView = TransducerView(
            of: CounterTransducer.self,
            initialState: initialState,
            proxy: currentProxy,
            output: Callback { @MainActor output in
                outputs.append(output)
                if outputs.count == 3 {
                    proxyChangeExpectation.fulfill()
                }
            }
        ) { state, input in
            observedStates.append(state)
            capturedInput = input
            return Text("Count: \(state.value)")
        }
        
        try await proxyChangeExpectation.await(timeout: .seconds(10))
        
        // Verify state was reset to initial state after proxy change
        #expect(outputs == [5, 6, 5]) // Back to initial state
        #expect(observedStates.last?.value == 5)
        
        cleanupView(window)
    }
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func proxyChangeCancelsRunningTransducer() async throws {
        enum LongRunningTransducer: Transducer {
            enum State: NonTerminal {
                case running, cancelled
                init() { self = .running }
            }
            enum Event { case start, cancel }
            typealias Output = String
            
            static func update(_ state: inout State, event: Event) -> String {
                switch (state, event) {
                case (.running, .cancel):
                    state = .cancelled
                    return "cancelled"
                default:
                    return ""
                }
            }
        }
        
        let proxy1 = LongRunningTransducer.Proxy()
        var proxy2 = LongRunningTransducer.Proxy()
        
        var observedOutputs: [String] = []
        var capturedInput: LongRunningTransducer.Proxy.Input?
        let cancelExpectation = Expectation()
        
        @State var currentProxy = proxy1
        
        let view = TransducerView(
            of: LongRunningTransducer.self,
            initialState: .running,
            proxy: currentProxy,
            output: Callback { @MainActor output in
                if !output.isEmpty {
                    observedOutputs.append(output)
                    if output == "cancelled" {
                        cancelExpectation.fulfill()
                    }
                }
            }
        ) { state, input in
            capturedInput = input
            return VStack {
                Text("State: \(state)")
                Button("Change Proxy") {
                    currentProxy = proxy2
                }
            }
        }
        
        let (hostingController, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        // Verify we can send events to first proxy
        #expect(capturedInput != nil)
        let firstInput = capturedInput
        
        // Change proxy by updating the view
        proxy2 = LongRunningTransducer.Proxy()
        hostingController.rootView = TransducerView(
            of: LongRunningTransducer.self,
            initialState: .running,
            proxy: proxy2,
            output: Callback { @MainActor output in
                if !output.isEmpty {
                    observedOutputs.append(output)
                }
            }
        ) { state, input in
            capturedInput = input
            return Text("State: \(state)")
        }
        
        // Allow time for proxy change to take effect
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Verify new input is different (new proxy)
        #expect(capturedInput !== firstInput)
        
        cleanupView(window)
    }
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func completionCallbackWithEffectTransducer() async throws {
        enum EffectTestTransducer: EffectTransducer {
            enum State: NonTerminal {
                case ready, processing, completed
                init() { self = .ready }
            }
            enum Event { case start, process }
            enum Effect: Equatable {
                case doWork
            }
            typealias Output = String
            typealias Env = Void
            
            static func update(_ state: inout State, event: Event) -> (Effect?, String) {
                switch (state, event) {
                case (.ready, .start):
                    state = .processing
                    return (.doWork, "")
                case (.processing, .process):
                    state = .completed
                    return (nil, "work_completed")
                default:
                    return (nil, "")
                }
            }
        }
        
        var completionCalled = false
        var completionValue: String?
        let completionExpectation = Expectation()
        let outputExpectation = Expectation()
        
        let proxy = EffectTestTransducer.Proxy()
        var capturedInput: EffectTestTransducer.Proxy.Input?
        
        let view = TransducerView(
            of: EffectTestTransducer.self,
            initialState: .ready,
            proxy: proxy,
            env: (),
            output: Callback { @MainActor output in
                if output == "work_completed" {
                    outputExpectation.fulfill()
                }
            },
            completion: { @MainActor output in
                completionCalled = true
                completionValue = output
                completionExpectation.fulfill()
            }
        ) { state, input in
            capturedInput = input
            return Text("State: \(state)")
        }
        
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        // Trigger the workflow
        try capturedInput?.send(.start)
        try capturedInput?.send(.process)
        
        try await outputExpectation.await(timeout: .seconds(10))
        try await completionExpectation.await(timeout: .seconds(10))
        
        #expect(completionCalled)
        #expect(completionValue == "work_completed")
        
        cleanupView(window)
    }
    
    // MARK: - Default Proxy Construction Tests
    
    @Test
    func proxyHasDefaultConstructor() async throws {
        enum TestTransducer: Transducer {
            enum State: NonTerminal {
                case idle
                init() { self = .idle }
            }
            enum Event { case test }
        }
        
        // Test that proxy can be created with default constructor
        let proxy = TestTransducer.Proxy()
        #expect(proxy.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        
        // Test that AsyncProxy also has default constructor
        let asyncProxy = Oak.AsyncProxy<TestTransducer.Event>()
        #expect(asyncProxy.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }
    
    // MARK: - Integration Tests with Simple Examples
    
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    @Test
    func simpleCounterIntegration() async throws {
        enum CounterTransducer: Transducer {
            enum State: NonTerminal, Equatable {
                case count(Int)
                init() { self = .count(0) }
                var value: Int {
                    if case .count(let v) = self { return v }
                    return 0
                }
            }
            enum Event { case increment, decrement }
            typealias Output = Int
            
            static func update(_ state: inout State, event: Event) -> Int {
                MainActor.assertIsolated()
                switch (event, state) {
                case (.increment, .count(let current)):
                    state = .count(current + 1)
                case (.decrement, .count(let current)):
                    state = .count(current - 1)
                }
                return state.value
            }
            
            static func initialOutput(initialState: State) -> Int? {
                initialState.value
            }
        }
        
        let proxy = CounterTransducer.Proxy()
        var output: Int = 0
        var outputs: [Int] = []
        var capturedInput: CounterTransducer.Proxy.Input?
        var observedStates: [CounterTransducer.State] = []
        // var capturedState: CounterTransducer.State?
        
        let expect5 = Expectation(minFulfillCount: 5)
        let expect2 = Expectation(minFulfillCount: 2)
        // let expect3 = Expectation()

        let view = TransducerView(
            of: CounterTransducer.self,
            initialState: .count(0),
            proxy: proxy,
            output: Callback { @MainActor in
                MainActor.assertIsolated()
                output = $0
                outputs.append($0)
                expect5.fulfill()
                switch $0 {
                case 0:
                    break
                case 1:
                    break
                case 2:
                    expect2.fulfill()
                case 3:
                    break
                default:
                    break
                }
            }
        ) { state, input in
            capturedInput = input
            observedStates.append(state)
            return Text("\(state.value)")
        }
        
        // Host the view properly
        let (_, window) = await hostView(view)
        await waitUntilViewAppeared(window: window)
        
        // Test increment
        try capturedInput?.send(.increment) // 1
        
        // Test multiple increments
        try capturedInput?.send(.increment) // 2
        try capturedInput?.send(.increment) // 3
        
        // Test decrement
        try capturedInput?.send(.decrement) // 2
        await #expect(throws: Never.self) { try await expect5.await(timeout: .seconds(1)) }
        #expect(expect2.isFulfilled)
        #expect(output == 2)
        #expect(outputs == [0,1,2,3,2])
        #expect(observedStates == [.count(0), .count(1), .count(2), .count(3), .count(2)])

        // Clean up
        cleanupView(window)
    }
}

#else
// SwiftUI and/or UIKit not available - TransducerView tests skipped

import Testing

@MainActor
struct TransducerViewTestsFallback {
    
    @Test
    func swiftUINotAvailable() async throws {
        #expect(Bool(false), "TransducerView tests require SwiftUI and UIKit. Run from Xcode with a run destination which has UIKit to execute full TransducerView test suite. This skip is expected when testing from command line.")
    }
}

#endif // canImport(SwiftUI)
