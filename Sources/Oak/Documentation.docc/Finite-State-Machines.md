# Understanding Finite State Machines

Finite state machines provide mathematical guarantees about application behavior by making all possible states and transitions explicit.

## The Problem with Implicit State

Most applications manage state implicitly through scattered boolean flags and optional properties:

```swift
class ViewController {
    var isLoading = false
    var hasError = false
    var data: [Item]?
    var errorMessage: String?
    
    func loadData() {
        // What if isLoading is already true?
        // What if hasError is true but errorMessage is nil?
        // How many total states are possible here?
    }
}
```

This approach creates several problems:

**State Explosion**: With multiple boolean flags, the number of possible states grows exponentially. Four boolean properties create 16 possible combinations, but most are invalid or undefined.

**Race Conditions**: Concurrent updates to multiple properties can create inconsistent intermediate states.

**Undefined Behavior**: Invalid state combinations lead to unpredictable application behavior.

**Testing Complexity**: All possible state combinations must be tested, including invalid ones.

## Finite State Machine Solution

A finite state machine (FSM) explicitly defines:

- **States**: All possible conditions the system can be in
- **Events**: All possible inputs that can trigger changes
- **Transitions**: Which events cause which state changes
- **Actions**: What happens during each transition

### Mathematical Guarantees

FSMs provide formal guarantees:

1. **Completeness**: Every (state, event) combination is handled
2. **Determinism**: Each (state, event) pair has exactly one outcome
3. **Reachability**: All states can be reached from the initial state
4. **Termination**: Terminal states are clearly defined

## Oak's FSM Implementation

Oak implements FSMs through the `Transducer` protocol:

```swift
enum LoginFlow: Transducer {
    // Explicit state definition
    enum State: Terminable {
        case start
        case enteringCredentials(email: String, password: String)
        case authenticating(email: String, password: String)
        case authenticated(User)
        case failed(Error)
        case completed
        
        var isTerminal: Bool {
            if case .completed = self { return true }
            return false
        }
    }
    
    // All possible events
    enum Event {
        case startLogin
        case updateEmail(String)
        case updatePassword(String)
        case submitCredentials
        case authenticationSucceeded(User)
        case authenticationFailed(Error)
        case loginComplete
    }
    
    // Pure transition function
    static func update(_ state: inout State, event: Event) -> Void {
        switch (state, event) {
        case (.start, .startLogin):
            state = .enteringCredentials(email: "", password: "")
            
        case (.enteringCredentials(_, let password), .updateEmail(let email)):
            state = .enteringCredentials(email: email, password: password)
            
        case (.enteringCredentials(let email, _), .updatePassword(let password)):
            state = .enteringCredentials(email: email, password: password)
            
        case (.enteringCredentials(let email, let password), .submitCredentials):
            state = .authenticating(email: email, password: password)
            
        case (.authenticating, .authenticationSucceeded(let user)):
            state = .authenticated(user)
            
        case (.authenticating, .authenticationFailed(let error)):
            state = .failed(error)
            
        case (.authenticated, .loginComplete):
            state = .completed
            
        case (.failed, .startLogin):
            state = .enteringCredentials(email: "", password: "")
            
        default:
            // Invalid transitions are explicitly ignored
            break
        }
    }
}
```

## Benefits of Explicit State Modeling

### Impossible States are Unrepresentable

```swift
// MVVM: All these combinations are possible
isLoading = true
hasData = true
hasError = true  // Loading with data AND error?

// Oak: Only valid states can exist
enum State {
    case loading        // Definitely loading, no data, no error
    case loaded(Data)   // Definitely has data, not loading, no error
    case error(Error)   // Definitely has error, not loading, no data
}
```

### Exhaustive Transition Handling

The compiler enforces complete event handling:

```swift
switch (state, event) {
case (.idle, .start): // Must handle every combination
case (.loading, .complete):
case (.loading, .fail):
// Compiler error if any combination is missing
}
```

### Predictable Behavior

Every state transition is deterministic:

```swift
var state = LoginFlow.State.start
LoginFlow.update(&state, event: .startLogin)
// state is guaranteed to be .enteringCredentials("", "")
```

## State Design Principles

### Use Enums for Distinct States

Prefer sum types (enums) over product types (structs) for state:

```swift
// Good: Mutually exclusive states
enum ConnectionState {
    case disconnected
    case connecting
    case connected(Session)
    case reconnecting(lastSession: Session)
}

// Avoid: Multiple properties that can create invalid combinations
struct ConnectionState {
    var isConnected: Bool
    var isConnecting: Bool
    var session: Session?
    var isReconnecting: Bool
}
```

### Include Relevant Data in States

States can carry associated data:

```swift
enum FormState {
    case editing(fields: [String: String], errors: [ValidationError])
    case validating(fields: [String: String])
    case valid(submissionData: SubmissionData)
    case submitting(submissionData: SubmissionData)
    case submitted(result: SubmissionResult)
}
```

### Model Terminal States Explicitly

Some states represent completion:

```swift
enum ProcessState: Terminable {
    case initializing
    case processing(progress: Double)
    case completed(result: Result)
    case cancelled
    case failed(Error)
    
    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed:
            return true
        case .initializing, .processing:
            return false
        }
    }
}
```

## Testing FSM Logic

FSMs are easy to test because transitions are pure functions:

```swift
func testLoginFlow() {
    var state = LoginFlow.State.start
    
    // Test transition
    LoginFlow.update(&state, event: .startLogin)
    
    // Verify result
    if case .enteringCredentials(let email, let password) = state {
        XCTAssertEqual(email, "")
        XCTAssertEqual(password, "")
    } else {
        XCTFail("Expected enteringCredentials state")
    }
}
```

## When to Use FSMs

FSMs excel when:

- **Clear Phases**: Your feature has distinct operational phases
- **Complex State**: Multiple interacting boolean flags create confusion
- **Race Conditions**: Concurrent operations cause state corruption
- **Error Recovery**: Different error types require different recovery paths
- **Audit Requirements**: You need clear state transition logs

FSMs may be overkill for:

- Simple views with minimal state
- Purely computational tasks
- Features with only trivial state changes

The key is recognizing when explicit state modeling provides value over implicit state management.