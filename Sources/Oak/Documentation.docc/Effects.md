# Effects and Side Effect Management

Effects provide Oak's mechanism for handling side effects while maintaining pure state transition logic. This separation enables predictable, testable state machines that can still interact with the external world.

## The Pure Update Function Foundation

Understanding Effects requires understanding Oak's core architectural principle: the pure `update` function. Every Oak transducer centers around this function:

```swift
static func update(_ state: inout State, event: Event) -> Output
// or for EffectTransducers:
static func update(_ state: inout State, event: Event) -> Effect?
static func update(_ state: inout State, event: Event) -> (Effect?, Output)
```

**Pure means:**
- No side effects whatsoever - no network calls, file operations, logging, or external interactions
- Deterministic - same inputs always produce same outputs
- No dependencies on external state or time
- Only transforms the provided state and returns a result

This purity is what makes Oak transducers predictable, testable, and debuggable. But real applications need to interact with the outside world - that's where Effects come in.

**Effects bridge the pure-impure divide:** The `update` function can create Effect descriptions safely (pure), but Oak's runtime executes them later (impure). This keeps state transitions predictable while enabling real-world functionality.

> For comprehensive coverage of the `update` function signatures, patterns, theoretical foundation, and implementation details, see <doc:Transducers>.

## Understanding Side Effects vs Effects

**Side Effect** (concept): Any operation that interacts with systems outside your state machine or produces observable changes beyond returning a value. Examples include network requests, file operations, or printing to console.

**Effect** (Oak's implementation): A declarative description of an async throwing function that will be executed by Oak's runtime. Effects are created safely in the pure `update` function, but the actual execution happens later under Oak's management.

## Understanding Side Effects

Side effects are operations that interact with systems outside your state machine:

- Network requests and HTTP calls
- File system operations
- Database queries
- Timer operations and delays
- Logging and analytics
- Hardware interactions
- UI updates beyond state changes

Oak's architecture requires that all side effects be handled through the Effect system, keeping the `update` function pure and deterministic.

## Effect Types

Oak provides two types of effects with different execution characteristics:

### Operation Effects

Operation effects perform asynchronous work and can send zero or more events back to the transducer during their lifecycle. Common examples include network requests and timers:

```swift
// Network request - external side effect, sends one event after completion
static func loadUserEffect(userId: String) -> Effect {
    Effect(id: "loadUser-\(userId)") { env, input in
        do {
            let user = try await env.userService.fetchUser(id: userId)
            try input.send(.userLoaded(user))
        } catch {
            try input.send(.userLoadFailed(error))
        }
    }
}

// Timer - minimal side effect, sends multiple events over time
static func timerEffect(interval: TimeInterval) -> Effect {
    Effect(id: "timer") { env, input in
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(interval))
            try input.send(.tick)
        }
    }
}
```

**Characteristics:**
- Executed asynchronously as managed Tasks
- Can send zero or more events during their lifecycle via Input
- Support cancellation via effect IDs
- Run concurrently with the transducer

### Action Effects

Action effects return zero or more events from their function, which are handled immediately in the transducer logic:

```swift
static func configurationEffect() -> Effect {
    Effect.action { env in
        let config = env.loadConfiguration()
        return [.configLoaded(config), .ready] // Returns events immediately
    }
}
```

**Characteristics:**
- Executed immediately and synchronously
- Return events directly from the function for immediate processing
- Events are processed before any operation effects start
- Useful for environment data import, immediate computations

## Effect Creation Patterns

### Basic Operation Effect

```swift
static func networkRequestEffect() -> Effect {
    Effect { env, input in
        let data = try await env.networkService.fetchData()
        try input.send(.dataReceived(data))
    }
}
```

### Effect with Cancellation ID

Use IDs to enable cancellation of ongoing effects:

```swift
static func searchEffect(query: String) -> Effect {
    Effect(id: "search-\(query)") { env, input in
        let results = try await env.searchService.search(query: query)
        try input.send(.searchResults(results))
    }
}
```

When a new search starts, the previous search effect is automatically cancelled.

### Error Handling in Effects

```swift
static func risky operationEffect() -> Effect {
    Effect { env, input in
        do {
            let result = try await env.riskyService.performOperation()
            try input.send(.operationSucceeded(result))
        } catch let error as NetworkError {
            try input.send(.networkError(error))
        } catch {
            try input.send(.unknownError(error))
        }
    }
}
```

### Composite Effects

Combine multiple effects for complex operations:

```swift
static func saveAndBackupEffect(data: Data) -> Effect {
    Effect { env, input in
        // Save locally first
        try await env.localStorage.save(data)
        
        // Then backup to remote
        try await env.remoteBackup.upload(data)
        
        try input.send(.saveCompleted)
    }
}
```

## Environment Design

The Environment (`Env`) provides dependencies to effects in a type-safe, testable way.

### Service Dependencies

```swift
struct Env: Sendable {
    var userService: @Sendable (String) async throws -> User
    var analyticsService: @Sendable (String) -> Void
    var localStorage: @Sendable (Data) throws -> Void
}
```

### Configuration Parameters

```swift
struct Env: Sendable {
    var maxRetries: Int
    var requestTimeout: TimeInterval
    var baseURL: URL
    var featureFlags: FeatureFlags
}
```

### Sendable Compliance

All environment properties must be `@Sendable` for safe concurrent access:

```swift
// Good: Sendable closure
var dataService: @Sendable () async throws -> [DataItem]

// Good: Sendable actor
var dataManager: DataManagerActor

// Avoid: Non-sendable references
var dataController: NSManagedObjectContext // Not Sendable
```

## Effect Lifecycle

### Automatic Cancellation

Effects are automatically cancelled when:

- The transducer reaches a terminal state
- A new effect with the same ID is created
- The SwiftUI view containing the transducer disappears

### Manual Cancellation

Cancel effects explicitly by returning cancellation effects:

```swift
static func cancelLoadingEffect() -> Effect {
    Effect.cancel(id: "dataLoading")
}
```

### Effect Ordering

Action effects always execute before operation effects:

```swift
static func update(_ state: inout State, event: Event) -> Effect? {
    switch (state, event) {
    case (.idle, .start):
        state = .starting
        return .sequence([
            logEffect("Starting operation"),  // Action: executes first
            loadDataEffect()                 // Operation: executes second
        ])
    }
}
```

## Testing Effects

### Mocking Environments

Create test environments with predictable behavior:

```swift
extension MyTransducer.Env {
    static var test: Self {
        Self(
            dataService: { MockData.items },
            logger: { _ in }, // No-op logger for tests
            analytics: { _ in } // No-op analytics
        )
    }
}
```

### Testing Effect Behavior

Test effects by verifying the events they send:

```swift
func testLoadDataEffect() async throws {
    let expectation = XCTestExpectation(description: "Data loaded")
    var receivedEvent: MyTransducer.Event?
    
    let input = MockInput { event in
        receivedEvent = event
        expectation.fulfill()
    }
    
    let env = MyTransducer.Env.test
    let effect = MyTransducer.loadDataEffect()
    
    try await effect.run(env: env, input: input)
    
    await fulfillment(of: [expectation], timeout: 1.0)
    
    if case .dataLoaded(let items) = receivedEvent {
        XCTAssertEqual(items.count, MockData.items.count)
    } else {
        XCTFail("Expected dataLoaded event")
    }
}
```

## Error Handling Strategies

### Graceful Degradation

Handle errors by transitioning to recovery states:

```swift
static func update(_ state: inout State, event: Event) -> Effect? {
    switch (state, event) {
    case (.loading, .loadFailed(let error)):
        if error.isRetryable {
            state = .retryable(error: error, attempt: 1)
            return retryEffect(delay: 1.0)
        } else {
            state = .failed(error)
            return alertEffect("Operation failed")
        }
    }
}
```

### Retry Logic

Implement retry with exponential backoff:

```swift
static func retryEffect(delay: TimeInterval) -> Effect {
    Effect { env, input in
        try await Task.sleep(for: .seconds(delay))
        try input.send(.retry)
    }
}
```

### Error Context Preservation

Maintain error context for debugging:

```swift
enum State {
    case failed(operation: String, error: Error, context: [String: Any])
}
```

## Performance Optimization

### Effect Reuse

Reuse effect instances when possible:

```swift
private static let refreshEffect = Effect { env, input in
    let data = try await env.dataService.refresh()
    try input.send(.refreshCompleted(data))
}

static func update(_ state: inout State, event: Event) -> Effect? {
    switch (state, event) {
    case (.idle, .refresh):
        return refreshEffect // Reuse instead of recreating
    }
}
```

### Avoid Heavy Computation in Effects

Keep effects focused on I/O operations:

```swift
// Good: Effect handles I/O, computation in update
static func processDataEffect(data: RawData) -> Effect {
    Effect { env, input in
        let processedData = await env.processor.process(data)
        try input.send(.dataProcessed(processedData))
    }
}

// Avoid: Heavy computation in effect
static func heavyComputationEffect(data: RawData) -> Effect {
    Effect { env, input in
        // Expensive computation blocks the effect system
        let result = performExpensiveCalculation(data)
        try input.send(.calculationComplete(result))
    }
}
```

## Common Effect Patterns

### Debounced Effects

Implement debouncing using effect IDs:

```swift
static func searchEffect(query: String) -> Effect {
    Effect(id: "search") { env, input in
        try await Task.sleep(for: .milliseconds(300)) // Debounce
        let results = try await env.searchService.search(query: query)
        try input.send(.searchResults(results))
    }
}
```

### Polling Effects

Create recurring operations:

```swift
static func pollStatusEffect() -> Effect {
    Effect(id: "polling") { env, input in
        while !Task.isCancelled {
            let status = try await env.statusService.checkStatus()
            try input.send(.statusUpdated(status))
            try await Task.sleep(for: .seconds(5))
        }
    }
}
```

### Cleanup Effects

Perform cleanup when leaving states:

```swift
static func update(_ state: inout State, event: Event) -> Effect? {
    switch (state, event) {
    case (.streaming, .stop):
        state = .idle
        return cleanupEffect()
    }
}

static func cleanupEffect() -> Effect {
    Effect.action { env in
        env.streamManager.closeConnections()
    }
}
```

Effects provide a powerful, type-safe way to handle side effects while maintaining the purity and predictability of your state machines. The key is keeping effects focused, testable, and properly integrated with your application's lifecycle.