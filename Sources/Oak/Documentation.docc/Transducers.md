# Transducers and EffectTransducers

Oak provides two main protocols for implementing finite state machines: `Transducer` for pure state transitions and `EffectTransducer` for state machines that need to perform side effects.

## Transducer: Pure State Machines

The `Transducer` protocol is designed for state machines that only perform pure computations without side effects.

### Basic Structure

```swift
enum SimpleCounter: Transducer {
    enum State: NonTerminal {
        case idle(count: Int)
    }
    
    enum Event {
        case increment
        case decrement
        case reset
    }
    
    typealias Output = Int
    
    static var initialState: State {
        .idle(count: 0)
    }
    
    static func update(_ state: inout State, event: Event) -> Output {
        switch (state, event) {
        case (.idle(let count), .increment):
            let newCount = count + 1
            state = .idle(count: newCount)
            return newCount
            
        case (.idle(let count), .decrement):
            let newCount = max(0, count - 1)
            state = .idle(count: newCount)
            return newCount
            
        case (.idle, .reset):
            state = .idle(count: 0)
            return 0
        }
    }
    
    static func initialOutput(initialState: State) -> Output? {
        if case .idle(let count) = initialState {
            return count
        }
        return nil
    }
}
```

### Key Characteristics

**Pure Functions**: The `update` function must be deterministic and free of side effects. No network calls, file operations, or other external interactions.

**Direct Output**: Returns output values directly from the `update` function.

**No Environment**: Simple transducers don't require external dependencies.

**Immediate Execution**: All state transitions happen synchronously.

## The Update Function: Theoretical Foundation

Oak's `update` function is a powerful abstraction that combines the classical finite state machine concepts of transition and output functions into a single, unified interface.

### Classical FSM Theory Background

In traditional finite state machine theory, automata are classified based on how they generate output:

**Moore Automata**: Output depends only on the current state
- Output function: `λ(state) → output`
- Outputs are stable and only change when state changes
- No timing glitches since output is purely state-dependent

**Mealy Automata**: Output depends on both current state and input event
- Output function: `λ(state, event) → output`
- Outputs can change immediately when inputs change
- More expressive but can have timing glitches in hardware implementations

### Oak's Unified Approach

Oak's `update` function elegantly combines both the transition function and output function:

```swift
// Classical FSM would have separate functions:
// δ(state, event) → new_state     (transition function)
// λ(state, event) → output        (output function - Mealy)
// λ(state) → output               (output function - Moore)

// Oak combines both into update:
static func update(_ state: inout State, event: Event) -> Output {
    // Transition: modify state in-place
    state = newState
    
    // Output: return based on state and/or event (flexible Mealy/Moore)
    return computedOutput
}
```

This unified approach provides several advantages:

**Flexibility**: Choose Moore-style (state-only), Mealy-style (state+event), or mixed approaches per transition:

```swift
static func update(_ state: inout State, event: Event) -> String {
    switch (state, event) {
    case (.idle, .start):
        state = .running
        return "Started"  // Mealy-style: output depends on event
        
    case (.running, .tick):
        state = .running
        return state.description  // Moore-style: output depends only on state
        
    case (.running, .stop):
        state = .stopped
        return "Transition from \(state) via \(event)"  // Mixed: uses both
    }
}
```

**Atomicity**: State transition and output generation happen atomically, preventing inconsistent intermediate states.

**Simplicity**: Single function interface reduces cognitive load compared to managing separate transition and output functions.

**Software Advantages**: Since Oak runs in software rather than hardware, timing glitches (a concern with Mealy machines in hardware) are not an issue, allowing full flexibility in output generation strategies.

### Moore vs Mealy: Theory vs Practice

While understanding the theoretical distinctions is valuable for context, **in practice, you rarely need to consciously choose between Moore and Mealy approaches**. Oak's unified `update` function is designed to be so intuitive that you naturally implement the right behavior for each situation.

The theoretical framework provides the robust foundation, but the interface is forgiving - you simply implement what feels natural:

```swift
static func update(_ state: inout State, event: Event) -> String {
    switch (state, event) {
    case (.idle, .start):
        state = .running
        return "Started"  // Naturally event-driven response
        
    case (.running, .tick):
        state = .running  
        return "Still running"  // Naturally state-based status
        
    case (.running, .stop):
        state = .stopped
        return "Stopped"  // Mix of both - and that's perfectly fine
    }
}
```

**The beauty of Oak's design**: You can't really "do it wrong" - the unified approach naturally guides you toward the appropriate output strategy for each transition. Whether your output ends up being Moore-style, Mealy-style, or mixed doesn't matter; what matters is that it correctly represents your application's logic.

The theoretical knowledge serves as background understanding of why the design works so well, rather than as a decision-making framework you need to actively apply.

### Initial Output Function

Oak also provides `initialOutput(initialState:)` for Moore-style automata, allowing states to have outputs even before any events are processed:

```swift
static func initialOutput(initialState: State) -> Output? {
    switch initialState {
    case .idle(let count):
        return count  // State has meaningful output from the start
    case .uninitialized:
        return nil   // No initial output until first transition
    }
}
```

This theoretical foundation enables Oak to provide both the predictability of Moore machines and the expressiveness of Mealy machines, while the software environment eliminates the timing concerns that traditionally favor Moore machines in hardware implementations.

## EffectTransducer: State Machines with Side Effects

The `EffectTransducer` protocol handles state machines that need to perform asynchronous operations or interact with external systems. For comprehensive coverage of Effects, see <doc:Effects>.

### Basic Structure

```swift
enum DataLoader: EffectTransducer {
    enum State: NonTerminal {
        case idle
        case loading
        case loaded([DataItem])
        case error(Error)
    }
    
    enum Event {
        case load
        case dataReceived([DataItem])
        case loadFailed(Error)
        case retry
    }
    
    struct Env: Sendable {
        var dataService: @Sendable () async throws -> [DataItem]
        var logger: @Sendable (String) -> Void
    }
    
    static var initialState: State {
        .idle
    }
    
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.idle, .load), (.error, .retry):
            state = .loading
            return loadDataEffect()
            
        case (.loading, .dataReceived(let items)):
            state = .loaded(items)
            return logEffect("Loaded \(items.count) items")
            
        case (.loading, .loadFailed(let error)):
            state = .error(error)
            return logEffect("Load failed: \(error)")
            
        default:
            return nil
        }
    }
    
    // Effects are declarative descriptions of side effects
    static func loadDataEffect() -> Effect {
        Effect { env, input in
            do {
                let items = try await env.dataService()
                try input.send(.dataReceived(items))
            } catch {
                try input.send(.loadFailed(error))
            }
        }
    }
    
    static func logEffect(_ message: String) -> Effect {
        Effect.action { env in
            env.logger(message)
        }
    }
}
```

### Key Characteristics

**Effect Return**: The `update` function returns `Effect?` instead of output directly.

**Environment Support**: Effects receive a typed environment containing dependencies.

**Pure Update Function**: Effects are created in the pure `update` function but executed later by Oak's runtime.

> For detailed information about Effect types, creation patterns, environment design, testing, and advanced usage, see <doc:Effects>.

## Choosing Between Transducer and EffectTransducer

### Use Transducer When:

- Pure computation only (no side effects)
- Simple state transformations
- Immediate, synchronous operations
- No external dependencies needed
- Direct output generation

**Examples**: Calculators, form validation, UI state management, data filtering.

### Use EffectTransducer When:

- Network requests or API calls  
- File system operations
- Database interactions
- Timer operations
- Logging or analytics
- Creating objects or "things"
- Any async operations
- Any side effects (whether obviously external or internal)

**Examples**: Data loading, authentication flows, file uploads, real-time updates, object creation, timer management.

## State Protocol Requirements

### NonTerminal States

For state machines that never reach a final state:

```swift
enum State: NonTerminal {
    case idle
    case active
    case paused
    // No terminal states
}
```

### Terminable States

For state machines with completion states:

```swift
enum State: Terminable {
    case start
    case processing
    case completed
    case cancelled
    case failed(Error)
    
    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed:
            return true
        case .start, .processing:
            return false
        }
    }
}
```

## Output Generation

### Transducer Output

Simple transducers generate output directly:

```swift
static func update(_ state: inout State, event: Event) -> String {
    switch (state, event) {
    case (.idle, .greet):
        state = .greeted
        return "Hello, World!"
    }
}
```

### EffectTransducer Output

Effect transducers can generate both effects and output:

```swift
static func update(_ state: inout State, event: Event) -> (Effect?, String) {
    switch (state, event) {
    case (.idle, .greet):
        state = .greeted
        let effect = logEffect("User greeted")
        return (effect, "Hello, World!")
    }
}
```

The choice between `Transducer` and `EffectTransducer` depends on whether your state machine needs to execute any async throwing functions or perform any side effects. Both action effects and operation effects execute side effects - whether obviously external (POST requests, file operations) or less obviously so (creating timers, objects, or logging). Start with `Transducer` for pure state transitions and upgrade to `EffectTransducer` when any form of side effect becomes necessary.

> For comprehensive coverage of Effects including environment design, error handling patterns, performance considerations, and testing strategies, see <doc:Effects>.