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

## Mathematical Foundations

Formally, a deterministic finite state machine is defined by the five-tuple **M = (Q, Σ, δ, q0, F)** where:

- **Q** is a finite set of states
- **Σ** is the input alphabet (the set of events)
- **δ** is the transition function `δ : Q × Σ → Q`
- **q0** is the initial state (an element of Q)
- **F** is the set of accepting (terminal) states (a subset of Q)

Two classical refinements specialise the output semantics:

- **Moore machines** add an output function `lambda_M: Q → Γ` that associates each state with an output symbol.
- **Mealy machines** add an output function `lambda_m: Q × Σ → Γ` that associates each transition with an output symbol.

Oak's `Transducer` protocol deliberately folds these theoretical concepts into a single Swift interface: the `update` function both applies the transition (`δ`) and returns an output value, letting you express Moore- or Mealy-style behaviour without switching abstractions. When you move to `EffectTransducer`, you are effectively extending the tuple with a side-effect algebra that describes asynchronous work while preserving the same mathematical core.

### Why FSMs Matter Beyond App Code

Finite state machines underpin critical infrastructure across many domains:

- **Hardware design** – digital circuits, CPU control units, and peripheral protocols
- **Networking** – TCP handshake negotiation, HTTP/2 frame parsing, Bluetooth and CAN bus controllers
- **Compilers & language tooling** – lexical analysers, parser generators, regular-expression engines
- **Robotics & industrial automation** – sequencing of actuators, safety interlocks, mission planners
- **Embedded and safety-critical systems** – avionics, automotive ECUs, medical devices

The same guarantees that make FSMs indispensable in these fields—determinism, predictability, and verifiability—translate directly into more reliable application logic when you apply them in Swift.

### Mathematical Guarantees

FSMs provide formal guarantees:

1. **Completeness**: Every (state, event) combination is handled
2. **Determinism**: Each (state, event) pair has exactly one outcome
3. **Reachability**: All states can be reached from the initial state
4. **Termination**: Terminal states are clearly defined

## Oak's FSM Implementation

Oak realises this mathematical model through the ``Transducer`` and ``EffectTransducer`` protocols. The pure `update(_:event:)` function combines the transition function `δ` with an output producer, while `initialOutput(initialState:)` covers Moore-style initial emissions. ``EffectTransducer`` keeps the same core but allows transitions to describe asynchronous work via effects without polluting state logic. For an end-to-end implementation walkthrough—covering inputs, outputs, proxies, and SwiftUI integration—see <doc:Transducers>.

## Benefits of Explicit State Modeling

For a deeper discussion of concrete patterns and Swift implementations, refer to <doc:Transducers>.

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

## FSM Actors and Runtime Isolation

Classic texts often stop with the abstract machine `(Q, Σ, δ, q0, F)`, but practical systems also need an **actor** that owns the state, accepts events, and emits outputs in a controlled way. This *FSM actor* is responsible for:

- **State encapsulation** – ensuring the only way to change state is via the transition function
- **Input ports** – accepting events from external sources, typically via queues or channels
- **Output ports** – publishing outputs or derived events to interested consumers
- **Isolation guarantees** – serialising access so transitions execute one at a time

Oak provides this actor layer through `TransducerView` and `ObservableTransducer`. They combine the pure `Transducer` or `EffectTransducer` definition with:

- A `Proxy`-backed input port (`Proxy.Input`) for enqueueing events
- An output pipeline built on ``Subject``/``Callback`` to notify observers
- Structured concurrency isolation (Swift actors or cooperative tasks) so transitions run sequentially and safely across threads

In other words, a `Transducer` describes *what* should happen, while the FSM actor describes *how* the environment interacts with that logic. Recognising this distinction clarifies why you pair pure update functions with runtime components such as `TransducerView`—it is the concrete manifestation of the FSM actor pattern inside SwiftUI.

Swift concurrency lets you express the same idea without creating an object at all. The static `run` helpers provided by Oak wrap a transducer inside an `async` function. When you call one of these helpers you supply initial state and an input stream; the function’s prologue initialises the FSM, the suspending loop acts like the actor’s method dispatcher by awaiting events and forwarding them to `update`, and the epilogue executes once the machine reaches a terminal state. Although nothing is allocated on the heap, the semantics mirror an object-based actor so closely that you can reason about lifecycle (initialise → handle events → tear down) using the same mental model.

One overload even hides the storage detail by creating a local `LocalStorage` instance for you. The body still follows the prologue/loop/epilogue structure, but you can think of it as instantiating a temporary actor whose state lives solely inside the `async` function:

```swift
public static func run(
    initialState: State,
    proxy: Proxy = Proxy(),
    env: Env = (),
    output: some Subject<Output>,
    systemActor: isolated any Actor = #isolation
) async throws -> Output
```

In practice you can wrap this `run` call inside a Swift `Task` to host the machine outside of the caller’s structured concurrency scope. Oak does exactly that in ``ObservableTransducer``: the view model launches a task, forwards events through a proxy, and keeps a handle so it can cancel the work or observe completion, effectively treating the task as an actor boundary.

> Tip: Internally the helper allocates a lightweight context object and storage wrapper, but both stay scoped to the `run` function. With compiler optimisations enabled the runtime can often keep them on the stack, so the ergonomic API does not impose a measurable heap-allocation penalty.

FSMs may be overkill for:

- Simple views with minimal state
- Purely computational tasks
- Features with only trivial state changes

The key is recognizing when explicit state modeling provides value over implicit state management.