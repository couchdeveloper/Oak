# Transducer Proxies in Oak Framework

## Overview

Transducer proxies are communication channels that enable event delivery between the external world and Oak's finite state machines. They serve as the primary interface for sending events into transducers while maintaining proper isolation and lifecycle management. Oak provides two distinct proxy implementations, each optimized for different concurrency patterns and flow control requirements.

## What are Transducer Proxies?

In Oak's architecture, transducer proxies act as event delivery mechanisms that bridge the gap between external event sources and the internal state machine processing. They encapsulate the complexity of event buffering, flow control, and lifecycle management while providing a clean, type-safe API for event injection.

### Core Responsibilities

1. **Event Delivery:** Transport events from external sources into the transducer's processing pipeline
2. **Flow Control:** Manage the rate of event delivery to prevent overwhelming the system
3. **Lifecycle Management:** Handle proper initialization and termination of event streams
4. **Isolation Boundaries:** Maintain safe communication across Swift concurrency isolation domains
5. **Error Handling:** Provide mechanisms for graceful and ungraceful termination scenarios

## Proxy Types and Architecture

### Standard Proxy (`Proxy<Event>`)

The standard `Proxy` uses `AsyncThrowingStream` for event delivery with bounded buffering. This implementation prioritizes throughput and non-blocking sends for high-frequency event scenarios.

#### Technical Architecture

**Buffering Strategy:**
- Uses `AsyncThrowingStream` with configurable buffer size (default: 8 events)
- Implements "oldest-dropping" buffering policy when capacity is exceeded
- Throws errors immediately when buffer overflow occurs

**Concurrency Model:**
- Event sending is synchronous from the caller's perspective
- Buffer overflow results in immediate error propagation
- No backpressure mechanism - fast producers can overwhelm slow consumers

**Use Cases:**
- High-frequency event scenarios where occasional event loss is acceptable
- Performance-critical paths where blocking is undesirable
- Systems with predictable event production rates

#### Event Delivery Patterns

**Direct Event Sending:**
```swift
let proxy = MyTransducer.Proxy()
try proxy.send(.userTappedButton)
try proxy.send(.dataReceived(data))
```

**Effect-Based Event Sending:**
```swift
static func networkEffect() -> Effect {
    Effect(id: "network", operation: { env, input in
        do {
            let data = try await env.api.fetchData()
            try input.send(.dataLoaded(data))
        } catch {
            try input.send(.networkError(error))
        }
    })
}
```

**Batch Event Sending:**
```swift
// Events can be sent in sequence
try proxy.send(events: { .started }, { .configured }, { .ready })
```

### SyncSuspendingProxy (`SyncSuspendingProxy<Event>`)

The `SyncSuspendingProxy` uses `AsyncThrowingChannel` for suspension-based flow control. This implementation prioritizes reliable delivery and natural backpressure over raw throughput.

#### Technical Architecture

**Backpressure Strategy:**
- Uses `AsyncThrowingChannel` which suspends senders until events are processed
- No buffering - each event delivery waits for complete processing
- Natural flow control prevents buffer overflow scenarios

**Concurrency Model:**
- Event sending suspends until the transducer's `update` function completes
- Effects execute asynchronously and do not block subsequent event processing
- Synchronizes producer speed with the transducer's event consumption rate
- **Important:** If the subject itself experiences backpressure, the transducer's `update` function will be blocked, preventing consumption of new events from the input stream

**Use Cases:**
- Critical event scenarios where every event must be processed
- Systems requiring precise flow control and backpressure
- Applications where event order and delivery guarantees are essential

#### Suspension-Based Event Patterns

**Async Event Sending:**
```swift
let proxy = SyncSuspendingProxy<Event>()
await proxy.send(.criticalEvent)  // Suspends until processed
await proxy.send(.followupEvent)  // Processes after previous completes
```

**Sequential Batch Processing:**
```swift
await proxy.send(events: 
    { .initialize },
    { .configure },
    { .start }
)
// Each event waits for the previous to complete
```

## Input Interface Design

Both proxy types provide an `Input` interface that serves as a lightweight, send-only handle for event delivery. This design pattern enables safe distribution of event-sending capabilities without exposing the full proxy API.

### Input Interface Benefits

1. **API Surface Reduction:** Exposes only event sending, hiding termination methods
2. **Safe Distribution:** Can be passed to effects and external components safely
3. **Isolation Compatibility:** Designed for safe use across concurrency boundaries
4. **Lifecycle Independence:** Input handles remain valid while proxy exists

### Input Usage Patterns

**Effect Integration:**
```swift
static func timerEffect() -> Effect {
    Effect(id: "timer", operation: { env, input in
        try await Task.sleep(for: .seconds(1))
        try input.send(.timerExpired)  // Standard proxy
        // OR
        await input.send(.timerExpired) // SyncSuspendingProxy
    })
}
```

**External Component Integration:**
```swift
class ExternalService {
    let input: MyTransducer.Proxy.Input
    
    init(input: MyTransducer.Proxy.Input) {
        self.input = input
    }
    
    func processData() async {
        // Service can send events without proxy access
        try? input.send(.dataProcessed)
    }
}
```

## Flow Control and Buffering Strategies

### Event Processing Model

Oak employs a sophisticated dual-layer event processing architecture:

- **Input Events (FIFO):** External events from proxies are processed in First-In-First-Out order
- **Action Effects (Immediate):** Events returned by action effects receive immediate precedence, creating depth-first processing chains

This hybrid model ensures external events are handled fairly while enabling immediate transducer responses and computational sequences.

### Standard Proxy Flow Control

The standard proxy implements a **fire-and-forget** model with bounded buffering:

```
Producer → [Buffer: 8 events] → Consumer
           ↓ (overflow)
         Error thrown
```

**Characteristics:**
- Fast event production is allowed until buffer fills
- Buffer overflow causes `send(_:)` to throw an error (does not automatically terminate transducer)
- No coordination between producer and consumer speeds
- Optimal for scenarios where event loss is acceptable

**Buffer Configuration:**
```swift
// Small buffer for memory-constrained environments
let proxy = Proxy<Event>(bufferSize: 4)

// Large buffer for burst event scenarios
let proxy = Proxy<Event>(bufferSize: 32)

// With initial event for immediate state transition
let proxy = Proxy<Event>(bufferSize: 8, initialEvent: .start)
```

### SyncSuspendingProxy Flow Control

The sync suspending proxy implements **coordinated flow control**:

```
Producer ←→ Channel ←→ Consumer
   ↑ (suspends)    ↑ (processes)
   └─ resumes when processing complete
```

**Characteristics:**
- Producer automatically adjusts to consumer processing speed
- No buffer overflow possible - suspension provides natural backpressure
- Guaranteed delivery of every event sent
- Each event waits for transducer `update` completion, but not effect execution

**Suspension Behavior:**
```swift
// This will suspend until event is fully processed
await proxy.send(.heavyProcessingEvent)

// Subsequent send waits for previous to complete
await proxy.send(.nextEvent)
```

## Lifecycle Management and Termination

### Graceful Termination

Both proxy types support graceful termination when transducers reach terminal states:

```swift
// Automatically called by Oak runtime
proxy.finish()  // Graceful stream termination
```

**Graceful Termination Characteristics:**
- Stream ends without error
- Pending events in buffer are processed
- No new events can be sent after termination
- `run` function completes normally

### Ungraceful Termination

For emergency shutdown scenarios, both proxies support forced termination:

```swift
// Manual cancellation with custom error
proxy.cancel(with: CustomError.emergencyShutdown)

// Default cancellation
proxy.cancel()  // Uses TransducerError.cancelled
```

**Ungraceful Termination Characteristics:**
- Stream ends with error
- Pending events may be discarded
- `run` function throws the provided error
- Immediate termination regardless of processing state

### Automatic Cleanup

Proxies automatically handle cleanup when deinitialized:

```swift
do {
    let proxy = MyTransducer.Proxy()
    // ... proxy usage
} // Proxy deinitialized here - automatically cancels associated transducer
```

## Concurrency and Thread Safety

### Isolation Domain Considerations

**Standard Proxy:**
- `Proxy<Event>` is `Sendable` only when `Event: Sendable`
- `Input` is always `Sendable` regardless of `Event` type
- Safe for concurrent sending from multiple producers

**SyncSuspendingProxy:**
- Requires `Event: Sendable` (enforced by type constraint)
- Both proxy and input are inherently `Sendable`
- Designed for cross-isolation-domain communication

### Concurrent Usage Patterns

**Multiple Producer Scenario:**
```swift
let proxy = MyTransducer.Proxy()
let input = proxy.input

// Safe concurrent access
Task { try input.send(.eventA) }
Task { try input.send(.eventB) }
Task { try input.send(.eventC) }
```

**Actor Isolation Integration:**
```swift
@MainActor
class UIEventSource {
    func sendUIEvent(to input: MyTransducer.Proxy.Input) {
        // Safe to call from MainActor
        try? input.send(.uiInteraction)
    }
}

actor BackgroundProcessor {
    func sendProcessedData(to input: MyTransducer.Proxy.Input) {
        // Safe to call from actor isolation
        try? input.send(.dataProcessed)
    }
}
```

## Error Handling and Resilience

### Error Categories

**Buffer Overflow (Standard Proxy Only):**
```swift
// Standard Proxy - throws on buffer overflow
do {
    try proxy.send(.event)  // throws
} catch Proxy<Event>.Error.droppedEvent(let description) {
    // Handle buffer overflow - transducer continues running
    print("Event dropped: \(description)")
} catch Proxy<Event>.Error.sendFailed(let description) {
    // Handle terminated proxy
    print("Send failed: \(description)")
}
```

**Important:** Buffer overflow only applies to Standard Proxy (`Proxy<Event>`) which has a throwing `send(_:)` method. SyncSuspendingProxy uses suspension-based backpressure and has a non-throwing async `send(_:)` method, so buffer overflow cannot occur.

The transducer only terminates if:
- The error is thrown from within an effect operation (unhandled errors in effects terminate transducers)
- The error propagates unhandled through user code that then terminates the transducer
- The caller doesn't catch the error and it bubbles up to terminate the transducer

**Termination Errors:**
```swift
// Standard Proxy - throws when terminated
do {
    try proxy.send(.event)
} catch {
    // Proxy has been terminated or cancelled
}

// SyncSuspendingProxy - does not throw but may suspend indefinitely if terminated
await proxy.send(.event)  // May suspend if proxy is terminated
```

### Error Recovery Strategies

**Graceful Degradation:**
```swift
func sendEventSafely(_ event: Event, to input: MyTransducer.Proxy.Input) {
    do {
        try input.send(event)
    } catch {
        // Log error and continue - don't crash application
        logger.warning("Failed to send event: \(error)")
    }
}
```

**Circuit Breaker Pattern:**
```swift
class EventSender {
    private var failureCount = 0
    private let maxFailures = 5
    
    func send(_ event: Event, to input: MyTransducer.Proxy.Input) {
        guard failureCount < maxFailures else {
            logger.error("Circuit breaker open - not sending event")
            return
        }
        
        do {
            try input.send(event)
            failureCount = 0  // Reset on success
        } catch {
            failureCount += 1
            logger.warning("Send failure \(failureCount)/\(maxFailures)")
        }
    }
}
```

## Integration with Oak Framework

### SwiftUI Integration

Proxies integrate seamlessly with SwiftUI through `TransducerView`:

```swift
struct ContentView: View {
    @State private var proxy = MyTransducer.Proxy()
    
    var body: some View {
        TransducerView(
            of: MyTransducer.self,
            initialState: .start,
            proxy: proxy,
            env: environment
        ) { state, input in
            VStack {
                Text("State: \(state)")
                Button("Send Event") {
                    // Standard Proxy - synchronous send works in action closures
                    try? input.send(.buttonTapped)
                }
            }
        }
    }
}
```

**Important SwiftUI Consideration:** Standard Proxy (`Proxy<Event>`) is typically preferred for SwiftUI integration because:
- SwiftUI action closures (button actions, gesture handlers) are **not async contexts**
- SyncSuspendingProxy's `await send()` cannot be called from these synchronous closures
- Standard Proxy's `try send()` works perfectly in action closures

**SyncSuspendingProxy in SwiftUI** requires async contexts:
```swift
Button("Async Action") {
    // This requires wrapping in a Task
    Task {
        await syncSuspendingProxy.send(.asyncEvent)
    }
}
```

### Effect System Integration

Proxies work with Oak's effect system for asynchronous event generation:

```swift
enum MyTransducer: EffectTransducer {
    static func networkEffect() -> Effect {
        Effect(id: "network", operation: { env, input in
            let data = try await env.networkService.fetchData()
            try input.send(.dataReceived(data))
        })
    }
    
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.idle, .startLoading):
            state = .loading
            return networkEffect()
        case (.loading, .dataReceived(let data)):
            state = .loaded(data)
            return nil
        }
    }
}
```

## Testing Strategies

### Proxy Testing Patterns

**Event Delivery Testing:**
```swift
func testEventDelivery() async throws {
    let proxy = MyTransducer.Proxy()
    let input = proxy.input
    
    // Test event sending
    try input.send(.testEvent)
    
    // Verify through transducer state changes
    // ... transducer testing logic
}
```

**Error Condition Testing:**
```swift
func testBufferOverflow() {
    let proxy = MyTransducer.Proxy(bufferSize: 1)
    
    // Fill buffer
    try? proxy.send(.event1)
    
    // This should throw
    XCTAssertThrowsError(try proxy.send(.event2)) { error in
        XCTAssertTrue(error is MyTransducer.Proxy.Error)
    }
}
```

### Custom Proxies

**Advanced Usage - Custom Proxy Implementation:**

While Oak's built-in proxies handle most use cases, custom proxy implementations are possible for advanced scenarios like testing or specialized flow control. Custom proxies must conform to both `TransducerProxy` and `TransducerProxyInternal` protocols.

> **Note:** This is advanced usage. `TransducerProxyInternal` is primarily intended for framework functionality, but it is public and can be implemented when needed.

**Example: Mock Proxy for Testing:**
```swift
class MockProxy<Event>: TransducerProxy, TransducerProxyInternal {
    private(set) var sentEvents: [Event] = []
    private let _id = UUID()
    private var _input: MockInput<Event>?
    
    init() {
        _input = MockInput(proxy: self)
    }
    
    var id: UUID { _id }
    
    var input: MockInput<Event> {
        _input!
    }
    
    func cancel(with error: Swift.Error?) {
        // Implementation for ungraceful termination
    }
    
    // TransducerProxyInternal requirements
    var stream: AsyncStream<Event> {
        // Return appropriate async sequence
        AsyncStream { continuation in
            // Implementation depends on testing needs
        }
    }
    
    func finish() {
        // Implementation for graceful termination
    }
    
    // Custom testing functionality
    func recordEvent(_ event: Event) {
        sentEvents.append(event)
    }
}

class MockInput<Event>: TransducerInput {
    weak var proxy: MockProxy<Event>?
    
    init(proxy: MockProxy<Event>) {
        self.proxy = proxy
    }
    
    func send(_ event: Event) throws {
        proxy?.recordEvent(event)
    }
}
```

**Alternative Testing Approach - Event Collection:**
```swift
class EventCollector<Event> {
    private(set) var events: [Event] = []
    
    func record(_ event: Event) {
        events.append(event)
    }
    
    func clear() {
        events.removeAll()
    }
}

func testTransducerLogic() async throws {
    let collector = EventCollector<MyTransducer.Event>()
    let proxy = MyTransducer.Proxy()
    
    // Send events and verify state transitions directly
    try proxy.send(.start)
    collector.record(.start)
    
    try proxy.send(.process)
    collector.record(.process)
    
    // Verify expected event sequence
    XCTAssertEqual(collector.events, [.start, .process])
}
```
```
```

## Performance Considerations

### Standard Proxy Performance

**Throughput Characteristics:**
- Very low overhead for event sending (microseconds)
- Optimal for high-frequency event scenarios
- Memory usage scales with buffer size
- No blocking on fast event production

**Performance Tuning:**
```swift
// High-throughput configuration
let proxy = Proxy<Event>(bufferSize: 64)

// Memory-constrained configuration  
let proxy = Proxy<Event>(bufferSize: 2)
```

### SyncSuspendingProxy Performance

**Latency Characteristics:**
- Higher per-event overhead due to suspension
- Latency scales with processing pipeline complexity
- Consistent memory usage (no buffering)
- Natural rate limiting through backpressure

**Performance Trade-offs:**
- Higher reliability at cost of throughput
- Predictable memory usage patterns
- Automatic flow control reduces system complexity
- Better suited for critical event scenarios

### Memory Management

**Proxy Lifecycle:**
```swift
// Proper proxy lifecycle management
class TransducerManager {
    private var proxy: MyTransducer.Proxy?
    private var transducerTask: Task<Void, Error>?
    
    func start() {
        proxy = MyTransducer.Proxy()
        transducerTask = Task {
            try await MyTransducer.run(
                initialState: .start,
                proxy: proxy!,
                env: environment
            )
        }
    }
    
    func stop() async {
        proxy?.cancel()
        try? await transducerTask?.value
        proxy = nil
        transducerTask = nil
    }
}
```

## Best Practices

### Proxy Selection Guidelines

**Choose Standard Proxy when:**
- High event frequency is expected
- Occasional event loss is acceptable
- Non-blocking event production is required
- Memory usage must be bounded and predictable
- **SwiftUI integration where events are sent from action closures (buttons, gestures, etc.)**

**Choose SyncSuspendingProxy when:**
- Every event must be processed
- Natural backpressure is desired
- Event ordering guarantees are critical
- System reliability is more important than throughput
- Events are primarily sent from async contexts (effects, Tasks, async functions)

### Event Design Patterns

**Event Granularity:**
```swift
// Good: Focused, single-purpose events
enum Event {
    case userTappedButton
    case dataLoaded(Data)
    case networkError(Error)
}

// Avoid: Overly broad events
enum Event {
    case uiEvent(UIEventType, Any)  // Too generic
    case systemEvent(SystemEventData)  // Too broad
}
```

**Event Batching:**
```swift
// For related events that should be processed together
enum Event {
    case batchEvents([IndividualEvent])
    case startBatch
    case addToBatch(IndividualEvent)
    case completeBatch
}
```

### Error Handling Best Practices

**Error Handling Strategy by Context:**

Buffer overflow is typically the only runtime error that occurs during normal transducer operation. Other errors (like proxy reuse) are usually programming errors that indicate more serious issues requiring immediate attention.

**In Effect Operations - Use `try`:**
```swift
static func timerEffect() -> Effect {
    Effect(id: "timer", operation: { env, input in
        // Use try - buffer overflow here indicates system overload
        // that should be handled explicitly or terminate the transducer
        try input.send(.timerTick)
    })
}

static func batchTimerEffect(count: Int) -> Effect {
    Effect(id: "batch-timer", operation: { env, input in
        for i in 0..<count {
            do {
                try input.send(.timerTick(i))
            } catch {
                // Handle overflow in high-frequency scenarios
                logger.warning("Timer overflow at tick \(i)")
                // Could implement backoff, larger buffer, or failure strategy
                throw error  // Terminate if critical
            }
        }
    })
}
```

**In SwiftUI Actions - Use `try?`:**
```swift
Button("User Action") {
    // Use try? - buffer overflow from user actions is extremely rare
    // However, if subject backpressure blocks the transducer, repeated button
    // presses can eventually overflow the buffer, resulting in silent failure
    try? input.send(.buttonTapped)
}

Button("Sign In") {
    // Even for critical actions, try? is often appropriate in UI contexts
    // IMPORTANT: Consider that if backpressure occurs, multiple sign-in events
    // may accumulate in the buffer and be processed sequentially when resolved.
    // Ensure transducer logic and effects handle duplicate events gracefully.
    try? input.send(.signInRequested)
}
```

**Important Consideration - Event Accumulation During Backpressure:**

When subject backpressure blocks the transducer and events accumulate in the Standard Proxy buffer, these events will be processed sequentially once backpressure resolves. **This is precisely why Oak uses the rigorous mathematical model of finite state machines** - to handle such scenarios deterministically and correctly:

```swift
// Example: Multiple sign-in attempts during backpressure
Button("Sign In") {
    try? input.send(.signInRequested)  // User presses multiple times
}

// When backpressure resolves, transducer processes each buffered event:
// .signInRequested -> handled by transducer logic
// .signInRequested -> handled by transducer logic  
// .signInRequested -> handled by transducer logic
// ... (for each buffered event)

// The transducer's mathematical model ensures correct behavior:
static func update(_ state: inout State, event: Event) -> Effect? {
    switch (state, event) {
    case (.idle, .signInRequested):
        state = .signingIn
        return signInEffect()
    case (.signingIn, .signInRequested):
        // Mathematical determinism: duplicate requests are ignored
        return nil
    case (.signedIn, .signInRequested):
        // State machine logic: already signed in - ignore
        return nil
    }
}
```

**The Transducer Advantage:**

Oak's transducer model specifically addresses edge cases like rapid user interactions through:

1. **Deterministic State Transitions:** Every (state, event) combination has a defined outcome
2. **Mathematical Rigor:** The finite state machine model prevents undefined behavior
3. **Predictable Responses:** Multiple identical events are handled consistently
4. **System Reliability:** Edge cases become normal, handled scenarios rather than bugs

**Best Practices for Reliable Event Handling:**

**Leverage Oak's Mathematical Foundation (Primary Approach):**
```swift
static func update(_ state: inout State, event: Event) -> Effect? {
    switch (state, event) {
    case (.idle, .signInRequested):
        state = .signingIn
        return signInEffect()
    case (.signingIn, .signInRequested):
        // Finite state machine rigor: duplicate events have defined behavior
        return nil
    // ... handle ALL (state, event) combinations explicitly
    }
}
```

**Additional Implementation Patterns:**

1. **Idempotent Effect Design:**
```swift
static func signInEffect() -> Effect {
    Effect(id: "sign-in", operation: { env, input in
        // Use effect ID for deduplication - only one sign-in per ID
        try await env.authService.signIn()
        try input.send(.signInCompleted)
    })
}
```

2. **UI State Management:**
```swift
Button("Sign In") {
    // Disable button based on state to prevent multiple presses
    try? input.send(.signInRequested)
}
.disabled(state == .signingIn)
```

**When Event Accumulation Might Be Problematic:**

The accumulation issue is more relevant for events that don't have natural state guards or where effects aren't naturally idempotent:

```swift
// Example: Analytics events or logging
Button("Track Action") {
    try? input.send(.userActionTracked(action: "buttonTap"))
}

// Or: Events with cumulative effects
Button("Add Item") {
    try? input.send(.addItemToCart(item))  // Each event might add another item
}
```

**Defensive Event Sending (for programmatic contexts):**
```swift
extension MyTransducer.Proxy.Input {
    func sendSafely(_ event: Event) {
        do {
            try send(event)
        } catch {
            // Log but don't crash - appropriate for non-critical automated events
            logger.error("Failed to send event \(event): \(error)")
        }
    }
}
```

**Graceful Degradation (for critical system events):**
```swift
func handleCriticalEvent(_ event: Event, input: MyTransducer.Proxy.Input) {
    do {
        try input.send(event)
    } catch {
        // Fallback mechanism for critical events
        handleEventLocally(event)
        scheduleRetry(event, input: input)
    }
}
```

### Testing Best Practices

**Event Flow Testing:**
```swift
func testEventFlow() async throws {
    let proxy = MyTransducer.Proxy()
    var states: [MyTransducer.State] = []
    
    let task = Task {
        var state = MyTransducer.initialState
        for await event in proxy.stream {
            let effect = MyTransducer.update(&state, event: event)
            states.append(state)
            // Handle effects...
        }
    }
    
    // Send test events
    try proxy.send(.start)
    try proxy.send(.process)
    try proxy.send(.complete)
    
    proxy.finish()
    try await task.value
    
    // Verify state progression
    XCTAssertEqual(states, [.started, .processing, .completed])
}
```

## Integration Patterns

### SwiftUI Integration

**State Observation:**
```swift
struct MyView: View {
    @State private var proxy = MyTransducer.Proxy()
    @State private var currentState = MyTransducer.initialState
    
    var body: some View {
        VStack {
            Text("Current: \(currentState)")
            
            Button("Action") {
                try? proxy.send(.userAction)
            }
        }
        .task {
            // Observe state changes
            for await newState in stateSequence {
                currentState = newState
            }
        }
    }
}
```

### Combine Integration

**Publisher Bridge:**
```swift
extension MyTransducer.Proxy {
    func eventPublisher() -> AnyPublisher<Event, Never> {
        PassthroughSubject<Event, Never>()
            .handleEvents(receiveOutput: { [weak self] event in
                try? self?.send(event)
            })
            .eraseToAnyPublisher()
    }
}
```

### Async/Await Integration

**Task-Based Event Processing:**
```swift
func processEventsAsynchronously(proxy: MyTransducer.Proxy) async {
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            // Event producer 1
            try? proxy.send(.event1)
        }
        
        group.addTask {
            // Event producer 2
            try? proxy.send(.event2)
        }
        
        group.addTask {
            // Event producer 3
            try? proxy.send(.event3)
        }
    }
}
```

The proxy system in Oak provides a robust, type-safe foundation for event-driven state machine architectures. By understanding the different proxy types and their characteristics, developers can choose the appropriate concurrency model and flow control strategy for their specific use cases while maintaining the architectural benefits of clean separation between event production and state management.