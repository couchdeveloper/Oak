# Your First State Machine

Learn Oak fundamentals by building a simple counter that demonstrates state transitions and event handling.

## Understanding the Problem

Traditional counter implementations often suffer from race conditions and undefined states. Consider this common pattern:

```swift
class CounterViewModel: ObservableObject {
    @Published var count = 0
    @Published var isLoading = false
    
    func increment() {
        // What if this is called multiple times quickly?
        // What if isLoading is true but we still increment?
        count += 1
    }
}
```

This approach leaves many questions unanswered about valid states and transitions.

## Oak's Approach

Oak requires explicit definition of all possible states and the events that trigger transitions between them.

### Defining State

Start by modeling your application's states as a Swift enum:

```swift
enum CounterState: NonTerminal {
    case idle(count: Int)
    case incrementing(count: Int)
    case decrementing(count: Int)
}
```

The `NonTerminal` protocol indicates this state machine never reaches a final state.

### Defining Events

Events represent user actions or system events that can trigger state changes:

```swift
enum CounterEvent {
    case increment
    case decrement
    case incrementComplete
    case decrementComplete
}
```

### Creating the Transducer

Combine state and events into a transducer that defines valid transitions:

```swift
import Oak

enum Counter: Transducer {
    enum State: NonTerminal {
        case idle(count: Int)
        case incrementing(count: Int)
        case decrementing(count: Int)
        
        var count: Int {
            switch self {
            case .idle(let count), .incrementing(let count), .decrementing(let count):
                return count
            }
        }
    }
    
    enum Event {
        case increment
        case decrement
        case incrementComplete
        case decrementComplete
    }
    
    typealias Output = Int
    
    static var initialState: State {
        .idle(count: 0)
    }
    
    static func update(_ state: inout State, event: Event) -> Output {
        switch (state, event) {
        case (.idle(let count), .increment):
            state = .incrementing(count: count)
            return count
            
        case (.idle(let count), .decrement):
            state = .decrementing(count: count)
            return count
            
        case (.incrementing(let count), .incrementComplete):
            let newCount = count + 1
            state = .idle(count: newCount)
            return newCount
            
        case (.decrementing(let count), .decrementComplete):
            let newCount = max(0, count - 1)
            state = .idle(count: newCount)
            return newCount
            
        // Ignore increment/decrement during processing
        case (.incrementing, .increment), (.incrementing, .decrement),
             (.decrementing, .increment), (.decrementing, .decrement):
            return state.count
            
        // Handle unexpected combinations
        default:
            return state.count
        }
    }
    
    static func initialOutput(initialState: State) -> Output? {
        return initialState.count
    }
}
```

## Key Concepts Demonstrated

**Pure Functions**: The `update` function contains no side effects and produces deterministic results for any given state and event combination.

**Explicit State Modeling**: Every possible state is defined in the type system. Impossible states cannot be represented.

**Exhaustive Event Handling**: All event combinations must be handled explicitly. The compiler enforces completeness.

**Output Generation**: Transducers can produce output values that represent the result of state transitions.

## What's Next

This basic transducer handles state transitions but doesn't integrate with UI yet. The next section shows how to connect this state machine to SwiftUI views.

See <doc:SwiftUI-Basics> for UI integration or <doc:Effects> for handling asynchronous operations.