# Oak Transducers - Finite State Machine Foundation

## Overview

Oak transducers are finite state machines with a Swift API that provides mathematical guarantees about state transitions. Instead of managing state updates manually, you define exactly what should happen for every possible (state, event) combination.

Oak addresses a common source of bugs in modern applications: race conditions and inconsistent state updates that occur when state transitions aren't explicitly defined. By making every state transition explicit, Oak eliminates undefined behavior by design.

The core benefit is predictability: every (state, event) combination has a defined outcome, making your application's behavior deterministic and testable.

## Why Finite State Machines Matter

### The Problem We've All Faced

Here's a sign-in flow I've seen in production more times than I care to count:

```swift
// Every iOS dev has written something like this
class SignInViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var user: User?
    @Published var error: Error?
    
    func signIn() {
        guard !isLoading else { return } // Feels like it should work...
        isLoading = true
        
        authService.signIn { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false // But what if this runs twice?
                switch result {
                case .success(let user):
                    self?.user = user
                    self?.error = nil
                case .failure(let error):
                    self?.error = error
                    // And somehow both success AND failure can execute
                }
            }
        }
    }
}
```

**What goes wrong in practice:**
- User double-taps the sign-in button → multiple network requests
- Slow network → user thinks it's broken, taps again
- Race between success and failure callbacks → inconsistent UI state
- Testing nightmare: how do you reproduce these edge cases?
- Production crashes that you can't debug because the state is corrupted

### How Oak Fixes This

Same feature, but with Oak's finite state machine approach:

```swift
enum SignInTransducer: EffectTransducer {
    enum State: Terminable {
        case idle
        case signingIn
        case signedIn(User)
        case error(Error)
        
        var isTerminal: Bool {
            switch self {
            case .signedIn, .error: return true
            default: return false
            }
        }
    }
    
    enum Event {
        case signInRequested
        case signInCompleted(User)
        case signInFailed(Error)
    }
    
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.idle, .signInRequested):
            state = .signingIn
            return signInEffect()
            
        case (.signingIn, .signInCompleted(let user)):
            state = .signedIn(user)
            return nil
            
        case (.signingIn, .signInFailed(let error)):
            state = .error(error)
            return nil
            
        case (.signingIn, .signInRequested):
            // Double-tap? No problem. The state machine just ignores it.
            return nil
            
        case (.signedIn, .signInRequested), (.error, .signInRequested):
            // Already finished? Also ignored.
            return nil
        }
    }
    
    static func signInEffect() -> Effect {
        Effect(id: "sign-in") { env, input in
            do {
                let user = try await env.authService.signIn()
                try input.send(.signInCompleted(user))
            } catch {
                try input.send(.signInFailed(error))
            }
        }
    }
}
```

**Why this approach works:**
- **No more race conditions**: State transitions happen one at a time
- **Explicit edge case handling**: Every (state, event) pair has a defined behavior
- **Testable**: You can test every possible transition
- **Debuggable**: The current state tells you exactly what's happening
- **Maintainable**: Adding features means adding states and transitions, not patching conditions

## Core Transducer Types

### 1. Transducer - Pure State Machines

For when you need rock-solid state logic without any I/O complexity.

**Use this when:**
- Form validation
- UI state (modal open/closed, tabs, etc.)
- Any logic that's purely computational
- You want to unit test without mocking anything

**Key benefits:**
- Zero side effects = zero surprises
- Completely synchronous = easy to reason about
- Deterministic = easy to test

**Real example - Form Validation:**
```swift
enum FormValidator: Transducer {
    enum State {
        case empty
        case invalid([String])
        case valid(FormData)
    }
    
    enum Event {
        case fieldChanged(Field, String)
        case validate
    }
    
    static func update(_ state: inout State, event: Event) -> ValidationResult {
        switch (state, event) {
        case (.empty, .fieldChanged(let field, let value)):
            state = .invalid([])
            return .fieldUpdated(field, value)
            
        case (.invalid, .validate):
            let errors = validateAllFields()
            if errors.isEmpty {
                state = .valid(constructFormData())
                return .validationPassed
            } else {
                state = .invalid(errors)
                return .validationFailed(errors)
            }
        }
    }
}
```

### 2. EffectTransducer - State Machines with Side Effects

This combines deterministic state logic with controlled async operations.

**Use this when:**
- Network requests
- Database operations
- Timers
- File I/O
- Any operation that touches the outside world

**Key characteristics:**
- State logic stays pure and testable
- Effects are automatically cancelled when appropriate
- Predictable event processing order
- Separation of concerns between state and side effects

**Real example - Data Loading Pattern:**
```swift
enum DataLoader: EffectTransducer {
    struct Env {
        let apiService: APIService
        let cache: CacheService
    }
    
    enum State: Terminable {
        case idle
        case loading
        case loaded(Data)
        case error(Error)
        
        var isTerminal: Bool {
            switch self {
            case .loaded, .error: return true
            default: return false
            }
        }
    }
    
    enum Event {
        case load
        case cacheChecked(Data?)
        case dataReceived(Data)
        case loadFailed(Error)
    }
    
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.idle, .load):
            state = .loading
            return checkCacheEffect()
            
        case (.loading, .cacheChecked(.some(let data))):
            state = .loaded(data)
            return nil
            
        case (.loading, .cacheChecked(.none)):
            return networkEffect()
            
        case (.loading, .dataReceived(let data)):
            state = .loaded(data)
            return cacheEffect(data)
            
        case (.loading, .loadFailed(let error)):
            state = .error(error)
            return nil
        }
    }
    
    static func checkCacheEffect() -> Effect {
        Effect(id: "cache-check") { env, input in
            let data = await env.cache.getData()
            try input.send(.cacheChecked(data))
        }
    }
    
    static func networkEffect() -> Effect {
        Effect(id: "network") { env, input in
            do {
                let data = try await env.apiService.fetchData()
                try input.send(.dataReceived(data))
            } catch {
                try input.send(.loadFailed(error))
            }
        }
    }
}
```

### 3. BaseTransducer - Composition and Coordination

Think of this as the "protocol" for building larger architectures out of smaller pieces.

**Use this when:**
- You need a coordinator that doesn't have its own state machine logic
- Building hierarchical flows (like navigation coordinators)
- Creating reusable component contracts
- You want the type safety without implementing the behavior

**The pattern:**
- Define the interface (State, Event, Output types)
- Let other components implement the actual logic
- Great for delegation and composition patterns

**Example - Application Coordinator:**
```swift
enum AppCoordinator: BaseTransducer {
    typealias State = AppState
    typealias Event = AppEvent
    typealias Output = AppOutput
    
    // Coordinates multiple transducers without implementing update()
    // Delegates to LoginTransducer, DashboardTransducer, etc.
}

enum AppState: Terminable {
    case launching
    case unauthenticated(LoginTransducer.State)
    case authenticated(DashboardTransducer.State)
    case terminating
    
    var isTerminal: Bool {
        self == .terminating
    }
}
```

## Advanced Architecture Patterns

### The Action Event Guarantee: Atomic State Transitions

Oak's most powerful architectural feature is this guarantee: **action events are processed synchronously and atomically before any other events can interfere**.

When your `update` function returns an **action** effect, Oak processes that event immediately, within the same execution context. No external events can interrupt this chain until all action events have been processed.

**Important**: Action effects can contain async operations, but the **state transition decisions** happen synchronously and atomically. Even if an action effect triggers slow async work, the state machine has already committed to the entire sequence of state changes before any external events can interfere.

**This enables:**

1. **Atomic State Transitions**: You can chain multiple state changes together in a single logical operation without worrying about external events disrupting the sequence.

2. **Invariant Preservation**: During complex workflows, you can maintain state invariants across multiple steps without defensive programming against unexpected interruptions.

3. **Simplified Error Handling**: Error recovery logic can assume a clean, predictable state without having to account for partially completed operations being interrupted.

4. **Deterministic Testing**: Test scenarios become much more predictable since you can reason about exact execution order within action effect chains.

```swift
static func update(_ state: inout State, event: Event) -> Effect? {
    switch (state, event) {
    case (.start, .beginWorkflow):
        state = .validating
        // This action event will process immediately, before any external events
        return .event(.performValidation)
        
    case (.validating, .performValidation):
        state = .processing  
        // This chains immediately after the previous action
        return .event(.executeBusinessLogic)
        
    case (.processing, .executeBusinessLogic):
        state = .complete
        // Entire chain executes atomically: start → validating → processing → complete
        return nil
    }
}
```

The `beginWorkflow` → `performValidation` → `executeBusinessLogic` sequence executes as one atomic operation. No user taps, network responses, or timers can interrupt this flow.

### The Stack Machine: How Oak Actually Processes Events

Oak implements a dual-layer event processing system:

1. **External events** (like user taps, network responses) go into a FIFO queue
2. **Action effects** (events returned directly from update functions) get immediate priority

This creates what's essentially a **stack machine embedded in your finite state machine**:

```swift
// Your input queue: [UserTap, NetworkResponse, Timer] (FIFO)

// When UserTap processes, it returns an action effect: [UpdateUI, LogAction]
// The queue becomes: [UpdateUI, LogAction, NetworkResponse, Timer]

// If UpdateUI also returns an action effect: [AnimateTransition]
// The queue becomes: [AnimateTransition, LogAction, NetworkResponse, Timer]
```

**Processing characteristics:**
- **Immediate feedback**: Action effects provide instant UI response
- **Depth-first computation**: Complex logic chains complete before external interruption
- **Predictable ordering**: Event processing follows defined precedence rules
- **Natural priorities**: Internal state changes take precedence over external stimuli

**Example - Document Creation Flow:**
```swift
enum DocumentEditor: EffectTransducer {
    enum State {
        case start
        case documentReady(Document)
        case savingDocument(Document)
        case saved(Document)
    }
    
    enum Event {
        // Public events - can come from external sources
        case startWorkflow
        case saveDocument
        
        // Private events - only generated internally by this transducer
        case documentCreated(Document)
        case validationCompleted(Document)
        case documentSaved
    }
    
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.start, .startWorkflow):
            // State remains 'start' - no transition needed until we have data
            // Action effect: immediate internal event processing
            return .event(.documentCreated(Document.template))
            
        case (.start, .documentCreated(let doc)):
            // Private event - we know this can only come from our action effect above
            // Now we transition because we have actual data
            state = .documentReady(doc)
            // Chain another private event
            return .event(.validationCompleted(doc))
            
        case (.documentReady, .validationCompleted(let doc)):
            // Private event - guaranteed to only happen in correct sequence
            // Validation complete, document remains ready
            return nil
            
        case (.documentReady(let doc), .saveDocument):
            // Public event - user can trigger this
            state = .savingDocument(doc)
            return saveDocumentEffect(doc)
            
        case (.savingDocument, .documentSaved):
            // Private event - only sent by our save effect
            if case .savingDocument(let doc) = state {
                state = .saved(doc)
            }
            return nil
            
        // Handle duplicate public events
        case (.documentReady, .startWorkflow):
            // Already have a document, ignore
            return nil
            
        case (.savingDocument, .startWorkflow), (.saved, .startWorkflow):
            // Already past start, ignore
            return nil
            
        case (.savingDocument, .saveDocument), (.saved, .saveDocument):
            // Already saving/saved, ignore
            return nil
            
        // Note: We don't need to handle invalid private event combinations
        // because we control exactly when they're emitted
        }
    }
}
```

This pattern demonstrates **stronger guarantees** through private events:

- **Public events** (like `.startWorkflow`, `.saveDocument`) can arrive at any time and must be handled defensively
- **Private events** (like `.documentCreated`, `.validationCompleted`) are only generated by the transducer itself, so we have complete control over when they occur
- The state can remain stable (`.start`) while private event chains execute
- We only need explicit handling for combinations involving **public** events - private events follow deterministic internal flows

### Effect Management

Oak provides two distinct types of effects for handling async operations:

**Two types of effects:**

1. **Action Effects** - Immediate responses (no async work):
```swift
// User taps button → immediate UI feedback
return .event(.showSpinner)

// Or multiple immediate steps
return .events([.validateInput, .updateUI, .logAction])
```

2. **Operation Effects** - Actual async work:
```swift
// Network request with automatic cleanup
Effect(id: "fetch-data") { env, input in
    let data = try await env.api.fetchData()
    try input.send(.dataReceived(data))
}
```

**Lifecycle management:**
- Effects are cancelled when transducers reach terminal states
- Effect IDs enable manual cancellation from update functions
- Automatic cleanup prevents resource leaks

### Error Handling and Resilience

Oak's finite state machine foundation provides structured error handling patterns.

**Graceful degradation patterns:**
```swift
// In your UI - events can fail gracefully
Button("Action") {
    try? input.send(.userAction) // Won't crash if transducer is done
}

// In effects - handle the real world
static func fetchEffect() -> Effect {
    Effect(id: "fetch") { env, input in
        do {
            try input.send(.result(data))
        } catch {
            // Transducer might be terminated, that's fine
            env.logger.log("Effect failed: \(error)")
        }
    }
}
```

**Recovery patterns:**
```swift
enum NetworkTransducer: EffectTransducer {
    enum State {
        case idle
        case loading
        case retrying(attempt: Int)
        case failed(Error)
        case loaded(Data)
    }
    
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.loading, .failed(let error)):
            state = .retrying(attempt: 1)
            return retryAfterDelay()
            
        case (.retrying(let attempt), .failed(let error)) where attempt < 3:
            state = .retrying(attempt: attempt + 1)
            return retryAfterDelay()
            
        case (.retrying, .failed(let error)):
            state = .failed(error) // Give up after 3 attempts
            return showErrorEffect()
        }
    }
}
```

## Developer Adoption Guide

### Learning Curve Considerations

Oak requires thinking in terms of states and events rather than objects and methods. The transition involves understanding finite state machine concepts and how they apply to application development.

**Common developer concerns:**

1. **"This seems overcomplicated"** 
   - For simple UI components, traditional approaches may be more direct
   - For complex state flows with async operations, Oak provides structure that prevents common bugs

2. **"I don't think in state machines"**
   - Start with simple cases: loading states (`.idle` → `.loading` → `.loaded`)
   - Existing logic often has implicit states that Oak makes explicit

3. **"The setup overhead seems high"**
   - Initial investment in structure provides long-term maintainability benefits
   - Debugging time typically decreases as state transitions become explicit

### Migration Strategy

**Incremental adoption approach:**

**Phase 1: Identify a problematic feature**
- Components with loading states that sometimes get stuck
- Form validation with edge cases
- Features with race condition bugs

**Phase 2: Convert async-heavy components**
- Replace ViewModels with EffectTransducers
- Centralize loading state management
- Use Oak's effect lifecycle management

**Phase 3: Build coordinators**
- Use BaseTransducer for navigation flows
- Connect multiple transducers for complex features
- Establish team patterns and conventions

### Team Adoption

**Design guidelines:**
1. **Design the state enum first** - Define all possible states before implementing transitions
2. **Handle everything explicitly** - Avoid `default:` cases that hide unhandled scenarios
3. **Keep effects pure** - Async operations should depend only on the environment
4. **Use terminal states** - Define clear end conditions for every flow

**Code review considerations:**
- Are all (state, event) combinations handled explicitly?
- Do the terminal states make sense for this flow?
- Will effects clean up properly when the transducer ends?
- Is the state enum clear and self-documenting?

## SwiftUI Integration

### TransducerView - Primary Integration

Oak integrates with SwiftUI through the TransducerView component:

```swift
struct LoginView: View {
    @State private var transducerState = LoginTransducer.initialState
    
    var body: some View {
        TransducerView(
            of: LoginTransducer.self,
            initialState: $transducerState,
            env: loginEnvironment
        ) { state, input in
            VStack {
                switch state {
                case .idle:
                    loginForm(input: input)
                case .signingIn:
                    progressView()
                case .signedIn(let user):
                    welcomeView(user: user)
                case .error(let error):
                    errorView(error: error, input: input)
                }
            }
        }
    }
}
```

### Building Hierarchical UIs

Parent views can coordinate multiple transducers. This is useful for complex flows like checkout or onboarding:

```swift
struct CheckoutView: View {
    @State private var paymentState = PaymentTransducer.initialState
    @State private var shippingState = ShippingTransducer.initialState
    @State private var coordinatorState = CheckoutCoordinator.initialState
    
    var body: some View {
        TransducerView(
            of: CheckoutCoordinator.self,
            initialState: $coordinatorState,
            env: checkoutEnvironment
        ) { state, coordinatorInput in
            VStack {
                // The coordinator watches child states and routes events
                PaymentSection(
                    state: paymentState,
                    coordinator: coordinatorInput
                )
                
                ShippingSection(
                    state: shippingState, 
                    coordinator: coordinatorInput
                )
            }
        }
    }
}
```

### State Observation and Reactivity

TransducerView provides automatic state observation without manual subscription management:

```swift
struct DashboardView: View {
    @State private var transducerState = DashboardTransducer.initialState
    
    var body: some View {
        TransducerView(
            of: DashboardTransducer.self,
            initialState: $transducerState,
            env: environment
        ) { state, input in
            // UI automatically updates when state changes
            VStack {
                header(for: state)
                content(for: state, input: input)
                footer(for: state)
            }
            .navigationTitle(titleForState(state))
            .onAppear { 
                try? input.send(.viewAppeared) 
            }
        }
        .onChange(of: transducerState) { newState in
            // Parent can react to state changes
            if case .error = newState {
                showErrorAlert = true
            }
        }
    }
}
```

## Testing

### Unit Testing Transducers

Finite state machines enable comprehensive testing by making all state transitions explicit and testable:

```swift
class SignInTests: XCTestCase {
    func testSignInFlow() {
        var state = SignInTransducer.State.idle
        
        // Test the happy path
        let effect1 = SignInTransducer.update(&state, event: .signInRequested)
        XCTAssertEqual(state, .signingIn)
        XCTAssertNotNil(effect1)
        
        // Test success
        let effect2 = SignInTransducer.update(&state, event: .signInCompleted(testUser))
        XCTAssertEqual(state, .signedIn(testUser))
        XCTAssertNil(effect2)
        
        // Test edge case: double-tap after success
        let effect3 = SignInTransducer.update(&state, event: .signInRequested)
        XCTAssertEqual(state, .signedIn(testUser)) // Should be unchanged
        XCTAssertNil(effect3)
    }
    
    func testEveryPossibleTransition() {
        // Finite state machines make exhaustive testing feasible
        let allStates: [SignInTransducer.State] = [
            .idle, .signingIn, .signedIn(testUser), .error(testError)
        ]
        let allEvents: [SignInTransducer.Event] = [
            .signInRequested, .signInCompleted(testUser), .signInFailed(testError)
        ]
        
        for state in allStates {
            for event in allEvents {
                var testState = state
                // This should never crash
                let effect = SignInTransducer.update(&testState, event: event)
                // Add assertions for expected behavior
            }
        }
    }
}
```

### Integration Testing with Effects

For testing the full flow including async operations:

```swift
func testNetworkFlow() async throws {
    let proxy = NetworkTransducer.Proxy()
    let mockEnv = NetworkTransducer.Env(
        apiService: MockAPIService(),
        cache: MockCacheService()
    )
    
    let task = Task {
        try await NetworkTransducer.run(
            initialState: .idle,
            proxy: proxy,
            env: mockEnv
        )
    }
    
    // Trigger the flow
    try proxy.send(.load)
    
    // Deterministic behavior enables predictable testing
    try await task.value
}
```

### Mock Environment Patterns

Environment patterns for testing:

```swift
struct MockEnvironment: Sendable {
    let apiService: MockAPIService
    let cache: MockCacheService
    let logger: MockLogger
    
    static let happyPath = MockEnvironment(
        apiService: MockAPIService(shouldSucceed: true),
        cache: MockCacheService(hasData: false),
        logger: MockLogger()
    )
    
    static let networkFailure = MockEnvironment(
        apiService: MockAPIService(shouldSucceed: false),
        cache: MockCacheService(hasData: false),
        logger: MockLogger()
    )
}
```

## Performance

### Memory Efficiency

Oak's design naturally leads to efficient memory usage:

**Characteristics:**
- No retained closures or delegate chains
- Automatic effect cleanup
- Value types for state prevent reference cycles
- Minimal allocations during state transitions

**Effect lifecycle management:**
- Effects die when transducers reach terminal states
- No zombie async operations
- Structured concurrency prevents resource leaks

### Computational Overhead

**State transitions characteristics:**
- Pure functions with minimal computational overhead
- In-place state mutation avoids copying
- Effects created only when needed
- Efficient event processing

**Concurrency characteristics:**
- Natural backpressure through proxy buffering
- Structured concurrency for predictable resource usage
- Automated thread management

### Scaling Patterns

**Hierarchical design:**
```swift
// Parent coordinators manage child transducers
enum AppFlow: BaseTransducer {
    // Routes events to the right place
    // Minimal coordination overhead
    // Scales naturally with composition
}
```

**Modular features:**
```swift
// Each feature is self-contained
enum PaymentFlow: EffectTransducer {
    // Independent state and effects
    // Compose with other features easily
    // Test in isolation
}
```

## Architectural Comparison

### Traditional Patterns vs. Oak

**MVVM evolution:**
```swift
// Traditional MVVM
class ViewModel: ObservableObject {
    @Published var state: ViewState = .loading
    // Manual state management
}

// Oak approach
struct FeatureTransducer: EffectTransducer {
    enum State { /* Every possible state defined */ }
    // Explicit state transitions
}
```

**Comparison with Redux:**
- Unidirectional data flow like Redux
- Mathematical guarantees about state transitions
- Native Swift concurrency integration
- Type safety with reduced boilerplate

### Migration from Existing Patterns

**From Combine-based architectures:**
- Replace `@Published` with transducer state observation
- Convert publisher chains to effect sequences
- Stop manually managing subscriptions

**From Coordinator patterns:**
- Use BaseTransducer for coordinator interfaces
- Implement child transducers for concrete features
- Keep the hierarchical flow you're used to

## Conclusion

Oak provides a structured approach to state management through finite state machine principles. The framework addresses common issues in event-driven applications by making state transitions explicit and deterministic.

**Oak characteristics:**
- **Predictable behavior**: Every (state, event) combination has a defined outcome
- **Reduced bugs**: Edge cases are handled explicitly by design
- **Controlled async operations**: Side effects are managed with automatic cleanup
- **Comprehensive testing**: Exhaustive state coverage through explicit transitions
- **Maintainable code**: Changes involve adding states/transitions rather than patching conditions

**Suitable for:**
- Applications requiring reliable, predictable behavior
- Complex state flows with multiple concurrent operations
- Teams focused on eliminating runtime bugs through design
- Projects prioritizing long-term maintainability

**Consider alternatives for:**
- Simple, static UIs with minimal state requirements
- Rapid prototypes where time-to-market is critical
- Teams not ready to adopt finite state machine thinking

Oak eliminates categories of bugs by making undefined behavior impossible through explicit state modeling. This approach trades upfront design investment for runtime reliability and maintainability.

> **Getting started**: Explore the examples in the Examples/ directory, review the API documentation, and consider converting a problematic feature to experience the approach firsthand.