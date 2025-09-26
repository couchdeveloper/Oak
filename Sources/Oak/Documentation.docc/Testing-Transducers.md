# Testing Transducers and Effects

Comprehensive testing strategies for Oak state machines, from pure state logic to complex effect interactions.

## Testing Pure State Transitions

Transducer update functions are pure, making them straightforward to test:

```swift
import Testing
import Oak

@Suite("Counter State Transitions")
struct CounterTests {
    
    @Test("Initial state is idle with zero count")
    func testInitialState() {
        let state = Counter.initialState
        #expect(state.count == 0)
    }
    
    @Test("Increment increases count")
    func testIncrement() {
        var state = Counter.State.idle(count: 5)
        let output = Counter.update(&state, event: .increment)
        
        #expect(output == 6)
        if case .idle(let count) = state {
            #expect(count == 6)
        } else {
            Issue.record("Expected idle state")
        }
    }
    
    @Test("Decrement respects minimum of zero")
    func testDecrementMinimum() {
        var state = Counter.State.idle(count: 0)
        let output = Counter.update(&state, event: .decrement)
        
        #expect(output == 0)
        if case .idle(let count) = state {
            #expect(count == 0)
        } else {
            Issue.record("Expected idle state")
        }
    }
}
```

## Testing State Machine Properties

### Exhaustive Transition Testing

Test all valid state and event combinations:

```swift
@Suite("Login Flow Transitions")
struct LoginFlowTests {
    
    @Test("All valid transitions", arguments: [
        (.start, .begin, .enteringCredentials),
        (.enteringCredentials, .submit, .authenticating),
        (.authenticating, .success, .authenticated),
        (.authenticating, .failure, .failed),
        (.failed, .retry, .enteringCredentials)
    ])
    func testValidTransitions(
        initial: LoginFlow.State,
        event: LoginFlow.Event,
        expected: LoginFlow.State
    ) {
        var state = initial
        _ = LoginFlow.update(&state, event: event)
        #expect(state == expected)
    }
    
    @Test("Invalid transitions are ignored")
    func testInvalidTransitions() {
        var state = LoginFlow.State.authenticated
        let originalState = state
        
        // These events should not change state when authenticated
        _ = LoginFlow.update(&state, event: .begin)
        #expect(state == originalState)
        
        _ = LoginFlow.update(&state, event: .submit)
        #expect(state == originalState)
    }
}
```

### Terminal State Testing

Verify terminal state behavior:

```swift
@Test("Terminal states cannot transition")
func testTerminalStates() {
    let terminalStates: [ProcessFlow.State] = [
        .completed(.success),
        .completed(.failure),
        .cancelled
    ]
    
    for var terminalState in terminalStates {
        #expect(terminalState.isTerminal)
        
        let originalState = terminalState
        _ = ProcessFlow.update(&terminalState, event: .retry)
        #expect(terminalState == originalState, "Terminal state should not change")
    }
}
```

## Testing Effects

### Mock Environments

Create predictable test environments:

```swift
extension DataLoader.Env {
    static func test(
        shouldSucceed: Bool = true,
        delay: TimeInterval = 0,
        data: [DataItem] = []
    ) -> Self {
        Self(
            dataService: {
                if delay > 0 {
                    try await Task.sleep(for: .seconds(delay))
                }
                if shouldSucceed {
                    return data
                } else {
                    throw TestError.networkError
                }
            },
            logger: { _ in } // No-op logger for tests
        )
    }
}

enum TestError: Error {
    case networkError
    case timeout
}
```

### Effect Execution Testing

Test effect behavior in isolation:

```swift
@Suite("Data Loading Effects")
struct DataLoaderEffectTests {
    
    @Test("Load data effect sends success event")
    func testLoadDataSuccess() async throws {
        let expectedData = [DataItem(id: 1, name: "Test")]
        let env = DataLoader.Env.test(data: expectedData)
        
        var receivedEvents: [DataLoader.Event] = []
        let input = MockInput { event in
            receivedEvents.append(event)
        }
        
        let effect = DataLoader.loadDataEffect()
        try await effect.run(env: env, input: input)
        
        #expect(receivedEvents.count == 1)
        if case .dataLoaded(let items) = receivedEvents.first {
            #expect(items == expectedData)
        } else {
            Issue.record("Expected dataLoaded event")
        }
    }
    
    @Test("Load data effect sends failure event on error")
    func testLoadDataFailure() async throws {
        let env = DataLoader.Env.test(shouldSucceed: false)
        
        var receivedEvents: [DataLoader.Event] = []
        let input = MockInput { event in
            receivedEvents.append(event)
        }
        
        let effect = DataLoader.loadDataEffect()
        try await effect.run(env: env, input: input)
        
        #expect(receivedEvents.count == 1)
        if case .loadFailed(let error) = receivedEvents.first {
            #expect(error is TestError)
        } else {
            Issue.record("Expected loadFailed event")
        }
    }
}
```

### Mock Input Helper

Create a reusable mock input for testing:

```swift
class MockInput<Event>: @unchecked Sendable {
    private let eventHandler: @Sendable (Event) throws -> Void
    private let lock = NSLock()
    private var _events: [Event] = []
    
    init(eventHandler: @escaping @Sendable (Event) throws -> Void) {
        self.eventHandler = eventHandler
    }
    
    var events: [Event] {
        lock.withLock { _events }
    }
    
    func send(_ event: Event) throws {
        lock.withLock { _events.append(event) }
        try eventHandler(event)
    }
}
```

## Integration Testing

### TransducerView Testing

Test SwiftUI integration using view testing:

```swift
@Test("TransducerView responds to state changes")
func testTransducerViewIntegration() async throws {
    let expectation = XCTestExpectation(description: "State change")
    
    struct TestView: View {
        @State private var state = Counter.initialState
        let onStateChange: (Counter.State) -> Void
        
        var body: some View {
            TransducerView(
                of: Counter.self,
                initialState: $state
            ) { state, input in
                VStack {
                    Text("Count: \(state.count)")
                    Button("Increment") {
                        try? input.send(.increment)
                    }
                }
                .onChange(of: state) { newState in
                    onStateChange(newState)
                }
            }
        }
    }
    
    let view = TestView { state in
        if state.count > 0 {
            expectation.fulfill()
        }
    }
    
    // Simulate button tap
    // Implementation depends on your testing framework
    
    await fulfillment(of: [expectation], timeout: 1.0)
}
```

### Full Workflow Testing

Test complete user workflows:

```swift
@Test("Complete login workflow")
func testLoginWorkflow() async throws {
    let env = LoginTransducer.Env.test(shouldSucceed: true)
    var state = LoginTransducer.initialState
    
    // Start login
    var effect = LoginTransducer.update(&state, event: .startLogin)
    #expect(state == .enteringCredentials)
    #expect(effect == nil)
    
    // Enter credentials
    effect = LoginTransducer.update(&state, event: .updateEmail("test@example.com"))
    #expect(effect == nil)
    
    effect = LoginTransducer.update(&state, event: .updatePassword("password"))
    #expect(effect == nil)
    
    // Submit credentials
    effect = LoginTransducer.update(&state, event: .submit)
    #expect(state == .authenticating)
    #expect(effect != nil)
    
    // Simulate successful authentication
    let mockInput = MockInput<LoginTransducer.Event> { _ in }
    try await effect!.run(env: env, input: mockInput)
    
    // Verify success event was sent
    if case .authenticationSucceeded = mockInput.events.first {
        // Process success event
        effect = LoginTransducer.update(&state, event: .authenticationSucceeded(testUser))
        #expect(state == .authenticated(testUser))
    } else {
        Issue.record("Expected authentication success event")
    }
}
```

## Property-Based Testing

Test state machine invariants:

```swift
@Test("State machine invariants")
func testStateMachineInvariants() {
    let allStates: [MyTransducer.State] = [
        .idle, .loading, .loaded([]), .error(TestError.networkError)
    ]
    
    let allEvents: [MyTransducer.Event] = [
        .load, .reload, .cancel, .dataReceived([]), .loadFailed(TestError.networkError)
    ]
    
    for initialState in allStates {
        for event in allEvents {
            var state = initialState
            let effect = MyTransducer.update(&state, event: event)
            
            // Invariant: update function always returns a valid state
            #expect(isValidState(state))
            
            // Invariant: terminal states don't transition
            if initialState.isTerminal {
                #expect(state == initialState, "Terminal state should not change")
                #expect(effect == nil, "Terminal state should not produce effects")
            }
        }
    }
}

func isValidState(_ state: MyTransducer.State) -> Bool {
    switch state {
    case .idle, .loading, .loaded, .error:
        return true
    }
}
```

## Performance Testing

Test state machine performance:

```swift
@Test("State transition performance")
func testStateTransitionPerformance() {
    let options = Test.TimeLimit(.minutes(1))
    
    measure(options: options) {
        var state = Counter.State.idle(count: 0)
        
        for _ in 0..<10000 {
            _ = Counter.update(&state, event: .increment)
        }
        
        if case .idle(let count) = state {
            #expect(count == 10000)
        }
    }
}
```

## Test Organization

### Test Structure

Organize tests by functionality:

```
Tests/
├── TransducerTests/
│   ├── CounterTests.swift
│   ├── LoginFlowTests.swift
│   └── DataLoaderTests.swift
├── EffectTests/
│   ├── NetworkEffectTests.swift
│   └── TimerEffectTests.swift
├── IntegrationTests/
│   ├── TransducerViewTests.swift
│   └── WorkflowTests.swift
└── Utilities/
    ├── MockInput.swift
    ├── TestEnvironments.swift
    └── TestHelpers.swift
```

### Test Utilities

Create reusable test utilities:

```swift
// Test data generators
enum TestData {
    static func randomUsers(count: Int) -> [User] {
        (0..<count).map { User(id: $0, name: "User \($0)") }
    }
    
    static func randomError() -> Error {
        [TestError.networkError, TestError.timeout].randomElement()!
    }
}

// State machine test helpers
extension StateMachine {
    static func testTransition(
        from initialState: State,
        event: Event,
        expectedState: State,
        expectedEffect: Effect? = nil
    ) {
        var state = initialState
        let effect = update(&state, event: event)
        
        #expect(state == expectedState)
        #expect(type(of: effect) == type(of: expectedEffect))
    }
}
```

Testing Oak state machines follows standard Swift testing practices but benefits from the predictable, pure nature of state transitions. Focus on testing state logic separately from effects, use mock environments for predictable effect testing, and verify complete workflows to ensure your application behaves correctly under all conditions.