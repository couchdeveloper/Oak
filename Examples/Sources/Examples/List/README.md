# LoadingList Demo

A comprehensive demonstration of state machine patterns for data loading workflows using the Oak framework. This example showcases production-ready patterns for handling async operations, error states, and complex UI flows in SwiftUI applications.

## Overview

This demo implements a data loading workflow that handles user input, service calls, loading states, error conditions, and data presentation. The implementation demonstrates Oak's state machine approach to managing complex application flows while maintaining type safety and predictable behavior.

### Key Components

- **Finite State Machine**: Explicit state modeling with Oak's transducer pattern
- **Async Service Integration**: Environment-based dependency injection for data services  
- **Modal State Management**: Sheet presentation, loading overlays, and error alerts
- **SwiftUI Integration**: Clean separation between state logic and view presentation
- **Error Handling**: Comprehensive error recovery with proper user feedback

### Architecture Benefits

The state machine approach provides several advantages over traditional imperative UI programming:

- **Explicit State Modeling**: All possible application states are defined in the type system
- **Predictable Transitions**: State changes follow explicit rules defined in the update function
- **Error Resilience**: Error conditions are handled as first-class state transitions
- **Type Safety**: Invalid states are impossible to represent
- **Testability**: Pure update functions enable comprehensive unit testing

### Framework-Agnostic Design

A key architectural advantage of Oak is the separation between state machine definition and execution context. Types conforming to the `Transducer` protocol define pure state machines without coupling to specific view systems or execution environments.

```swift
// Pure state machine definition - no UI dependencies
extension LoadingList.Transducer: EffectTransducer {
    typealias State = Utilities.State<Data, Sheet>
    
    public static func update(_ state: inout State, event: Event) -> Self.Effect? {
        // Pure state transition logic
    }
}
```

**Integration Flexibility:**

The same transducer definition can be integrated into different execution contexts:

- **SwiftUI Integration**: Using `TransducerView` for reactive UI updates
- **Observable Integration**: Using transducer actors for data layer operations  
- **Standalone Execution**: Running state transitions directly without actors
- **Testing**: Executing state machines in isolation for unit testing

This separation enables:
- **View System Independence**: Not tied to SwiftUI, UIKit, or any specific UI framework
- **Reusable Business Logic**: Same state machine across different presentation layers
- **Testing Isolation**: State logic can be tested without UI dependencies
- **Cross-Platform Potential**: State machines can run on different platforms with appropriate adapters

## State Design Patterns

### Input-in-State Pattern

The implementation demonstrates a pattern where actor components (like input channels) are stored directly in the state rather than passed through effect closures. This approach eliminates closure complexity and improves type safety.

```swift
/// Context contains actor components accessible to the update function
struct Context {
    let input: LoadingList.Transducer.Input
}

enum State<Data, Sheet>: NonTerminal {
    case start  // Initial state
    case idle(Content, Context)  // Operational state with context
    case modal(Content, Modal, Context)  // Modal state with context
}
```

**Benefits:**
- Actions can be created directly in state transitions without complex effect chains
- Type system enforces context availability in operational states
- Eliminates optional chaining for actor components
- Simplifies action creation and event sending

### Explicit Start State

Rather than using nested optional values to represent unconfigured states, this implementation uses an explicit `start` state:

```swift
enum State {
    case start                    // Initial state - clear and explicit
    case idle(Content, Context)   // Configured operational state  
    case modal(Content, Modal, Context)  // Modal presentation state
}
```

**Advantages:**
- Clear semantics: `.start` vs confusing `.idle(.empty(nil))`
- Self-documenting state transitions
- Better debugging experience with explicit state names
- Eliminates edge cases around unconfigured nested states

### Optional Associated Data for Configuration

States use optional associated values to distinguish between "exists but unconfigured" and "configured and ready". This pattern significantly reduces the number of required states by avoiding intermediate configuration states.

```swift
enum Content {
    case empty(Empty?)  // nil = unconfigured, needs setup
    case data(Data)     // always configured when present
}

enum Modal {
    case loading(Loading?)  // nil = unconfigured, needs setup
    case error(Error)       // always configured when present
    case sheet(Sheet?)      // nil = unconfigured, needs setup
}
```

**State Reduction Benefits:**

Without this pattern, each configurable component would require separate states:

```swift
// WITHOUT optional associated data - many more states needed
enum State {
    case start
    case configuringEmpty           // Intermediate state
    case idle(Content)
    case configuringSheet          // Intermediate state  
    case modal(Content, Modal)
    case configuringLoading        // Intermediate state
    case modalLoading(Content, Modal)
    // ... exponential growth of intermediate states
}
```

**Oak's Synchronous Action Effects Enable This Pattern:**

This pattern becomes feasible because Oak provides synchronous action effects that can configure and transition states in a single update cycle:

```swift
case (.start, .configureContext(let context)):
    // Synchronously configure empty state and transition - no intermediate state needed
    let emptyState = State.Empty(
        title: "Info",
        description: "No data available. Press Start to load items.",
        actions: [.init(id: "start", title: "Start", action: actionClosure)]
    )
    state = .idle(.empty(emptyState), context)  // Direct transition to configured state
    return nil
```

**Key Advantages:**

- **Fewer States**: Avoids exponential growth of intermediate "configuring" states
- **Atomic Transitions**: Configuration and state transition happen together
- **Type Safety**: Optional values clearly indicate configuration status
- **Simplified Logic**: No need to handle intermediate configuration states in the update function

**Why This Works in Oak:**

Traditional state machines often require intermediate states because configuration is asynchronous. Oak's synchronous action effects allow immediate configuration during state transitions, making the optional associated data pattern both safe and practical.

## Error Handling Strategy

### Critical Error Handling: Preventing Transducer Hangs

The implementation makes a crucial distinction between service errors and system errors to prevent transducer hangs:

```swift
static func serviceLoadEffect(parameter: String) -> Self.Effect {
    Effect(isolatedOperation: { env, input, systemActor in
        do {
            let data = try await env.service(parameter)
            try input.send(.serviceLoaded(data))
        } catch {
            // Convert service errors to events - do NOT throw service errors through the system
            try input.send(.serviceError(error))
        }
    })
}
```

**Critical Principle: Prevent Hanging States**

If a service fails and we don't send a completion event, the transducer remains in the loading state indefinitely. Users see a perpetual loading indicator with no way to recover. This is why:

- **Service errors MUST be converted to events** - ensures the transducer receives a response
- **System errors (buffer overflow) MAY be thrown** - terminates the transducer rather than hanging
- **The transducer must always receive a response** from async operations

**When Service Error Handling Fails:**

If `input.send(.serviceError(error))` itself fails (buffer overflow), the caught error propagates and terminates the transducer. This is the correct behavior - if the system cannot process completion events, termination is preferable to hanging.

### Input Buffer Overflow: When Error Muting is Appropriate

Different error handling strategies are required based on the execution context and consequences of failure:

```swift
// UI Actions: Error muting may be tolerable - synchronous, non-throwing context
let actionClosure: @Sendable () -> Void = {
    try? context.input.send(.intentShowSheet)
}

// Service Completions: Error propagation is required - async operation must complete
try input.send(.serviceLoaded(data))
try input.send(.serviceError(error))
```

**UI Action Context (Error Muting Acceptable):**
- **Synchronous execution**: Button actions cannot be `async throws`
- **User input context**: Buffer overflow is extremely rare during user interactions
- **Acceptable failure mode**: Ignored user input is better than app crash
- **Recovery mechanism**: User can retry the action immediately

**Service Completion Context (Error Propagation Required):**
- **Async operation**: Effect must signal completion to prevent hanging
- **Critical for state consistency**: Transducer must receive response events
- **Rare but critical**: Buffer overflow here indicates system-level problems
- **Termination preferable**: Better to terminate than hang indefinitely

**Buffer Overflow Scenarios:**
- **UI Actions**: Extremely rare - would require user to tap buttons faster than the system can process
- **Service Completions**: Indicates serious system issues - infinite event loops or flooding
- **System State**: When buffer overflow occurs during critical operations, termination is the safest response

## User Flow

The application implements a complete data loading workflow with the following user interaction patterns:

### Primary Flow
1. **Initial State**: Application starts with an empty content view displaying a message and "Start" button
2. **Input Collection**: User taps "Start" → Sheet appears requesting parameter input
3. **Loading Initiation**: User confirms input → Sheet dismisses, loading overlay appears
4. **Data Presentation**: Service completes → Loading overlay dismisses, data list appears

### Error Recovery Flow  
1. **Error Occurrence**: Service fails → Error alert appears over current content
2. **Error Acknowledgment**: User dismisses alert → Returns to empty state with retry option
3. **Retry Mechanism**: User can initiate new loading attempt

### Cancellation Flow
1. **Loading Cancellation**: User cancels during loading → Returns to previous content state
2. **Sheet Cancellation**: User cancels input sheet → Returns to empty state

## State Transitions

The state machine explicitly handles all possible state transitions:

```swift
public static func update(_ state: inout State, event: Event) -> Self.Effect? {
    switch (state, event) {
    // Bootstrap sequence
    case (.start, .viewOnAppear):
        return configureContextEffect()
        
    case (.start, .configureContext(let context)):
        // Configure initial empty state with actions
        state = .idle(.empty(emptyState), context)
        return nil
        
    // User interaction flows
    case (.idle(.empty(_), let context), .intentShowSheet):
        // Present input sheet
        state = .modal(state.content, .sheet(sheet), context)
        return nil
        
    case (.modal(let content, .sheet(_), let context), .intentSheetCommit(let parameter)):
        // Start loading with cancel capability
        state = .modal(content, .loading(loadingState), context)
        return serviceLoadEffect(parameter: parameter)
        
    // Service completion handling
    case (.modal(_, .loading(_), let context), .serviceLoaded(let data)):
        state = .idle(.data(data), context)
        return nil
        
    case (.modal(_, .loading(_), let context), .serviceError(let error)):
        state = .modal(.empty(retryState), .error(error), context)
        return nil
        
    // Error and cancellation handling
    case (.modal(_, .error, let context), .intentAlertConfirm):
        state = .idle(.empty(startState), context)
        return nil
        
    case (.modal(let content, .loading(_), let context), .cancelLoading):
        state = .idle(content, context)
        return nil
        
    default:
        return nil
    }
}
```

## Environment and Dependency Injection

The implementation uses environment-based dependency injection to provide clean separation between business logic and external dependencies. The environment provider is typically the transducer actor, and since SwiftUI Views can act as transducer actors, this enables leveraging SwiftUI's environment system directly.

```swift
struct Env {
    let service: (String) async throws -> Data
    let input: Input
}

// SwiftUI Environment integration
extension EnvironmentValues {
    @Entry var dataService: (String) async throws -> LoadingList.Transducer.Data = { _ in
        throw NSError(domain: "DataService", code: -1, 
                     userInfo: [NSLocalizedDescriptionKey: "Data service not configured"])
    }
}
```

**Environment Flow:**

1. **SwiftUI View as Transducer Actor**: The view acts as the transducer actor and environment provider
2. **Environment Injection**: SwiftUI's environment system provides dependencies to the view
3. **Transducer Environment**: The view constructs the transducer environment from SwiftUI environment values
4. **Effect Environment Access**: Only effects receive the environment directly from the transducer actor
5. **State Environment Import**: Action effects can "import" environment data into the state through events

**Environment Import Pattern:**

Since only effects have access to the environment, action effects are used to import environment data (including the transducer's Input/proxy) into the state, making it accessible to the update function:

```swift
// Action effect imports environment data into state
static func configureContextEffect() -> Self.Effect {
    Effect(isolatedAction: { env, isolated in
        // Effect has access to environment and can import data
        return .configureContext(State.Context(
            input: env.input,           // Import Input from environment
            service: env.service        // Import other dependencies
        ))
    })
}

// Update function receives imported environment data through events
case (.start, .configureContext(let context)):
    // Environment data now available in state through context
    state = .idle(.empty(emptyState), context)
    return nil
```

This pattern enables the Input-in-State approach where actor components become part of the state rather than being passed through effect closures.

```swift
struct MainView: View {
    @Environment(\.dataService) private var dataService  // SwiftUI environment injection
    
    var body: some View {
        TransducerView(
            // ... 
            env: LoadingList.Transducer.Env(
                service: dataService,  // Pass environment dependency to transducer
                input: proxy.input
            )
            // ...
        )
    }
}
```

This pattern enables:
- Easy testing with mock services
- Runtime service configuration
- Clean separation of concerns
- Type-safe dependency management
- **Seamless integration with SwiftUI's environment system**

## SwiftUI Integration

The state machine integrates with SwiftUI through the TransducerView pattern:

```swift
struct MainView: View {
    @State private var proxy = LoadingList.Transducer.Proxy()
    @Environment(\.dataService) private var dataService
    
    var body: some View {
        TransducerView(
            of: LoadingList.Transducer.self,
            initialState: .start,
            proxy: proxy,
            env: LoadingList.Transducer.Env(
                service: dataService,
                input: proxy.input
            ),
            completion: nil
        ) { state, input in
            ContentView(state: state, input: input)
        }
    }
}
```

### Modal Presentation

Sheet presentation uses SwiftUI's item-based approach with Identifiable conformance:

```swift
struct Sheet: Identifiable {
    var id: String = ""
    let title: String
    let description: String
    let `default`: String
    let commit: (String) -> Void
    let cancel: () -> Void
}

// In the view:
.sheet(item: .constant(state.sheet), onDismiss: {
    try? input.send(.viewSheetDidDismiss)
}) { sheet in
    InputSheetView(sheet: sheet)
}
```

This approach provides better type safety and eliminates manual boolean state management.

## Development Insights

### Implementation Timeline

This comprehensive implementation required approximately 4 hours of development time, including:

- State machine design and implementation
- Error handling strategy development  
- SwiftUI integration patterns
- Testing and validation
- Documentation

### Pattern Reusability

The established patterns provide reusable templates for:

- Async data loading workflows
- Modal state management
- Error handling and recovery
- User input collection
- Service integration patterns

### Type Safety Benefits

The state machine approach provides several type safety advantages:

- Invalid states cannot be represented in the type system
- All state transitions are explicitly defined
- Compiler enforces exhaustive case handling
- Refactoring is safer with compile-time validation

## Testing Strategy

The implementation supports comprehensive testing through:

### Mock Service Integration
```swift
static func previewDataService() -> (String) async throws -> LoadingList.Transducer.Data {
    return { parameter in
        // Simulate network delay and failures
        try await Task.sleep(nanoseconds: UInt64.random(in: 500_000_000...5_000_000_000))
        
        if Int.random(in: 1...2) == 1 {
            throw NSError(domain: "PreviewDataService", code: 500, 
                         userInfo: [NSLocalizedDescriptionKey: "Simulated network error"])
        }
        
        return LoadingList.Transducer.Data(items: mockItems)
    }
}
```

### State Transition Testing
The pure update function enables isolated testing of all state transitions without UI dependencies.

### SwiftUI Previews
Multiple preview configurations test different scenarios:
- Normal operation with mock data
- Error conditions with failing services
- Different loading states and timing

## Conclusion

This implementation demonstrates production-ready patterns for complex UI state management using Oak's finite state machine approach. The explicit state modeling, comprehensive error handling, and type-safe transitions provide a robust foundation for building reliable user interfaces.

The patterns established here serve as reusable templates for similar workflows throughout an application, promoting consistency and reducing development time for future features.

