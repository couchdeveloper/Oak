# SwiftUI Integration Basics

Oak provides two primary ways to integrate state machines with SwiftUI: `TransducerView` for declarative view composition and `ObservableTransducer` for view-model patterns.

## Integration Options

Oak offers two approaches for SwiftUI integration:

**`TransducerView`** (Recommended): A SwiftUI view that directly embeds your transducer, managing its lifecycle automatically. Best for most use cases where you want declarative, reactive UI updates.

**`ObservableTransducer`**: An `@Observable` class that wraps your transducer for view-model patterns. Useful when you need to share state across multiple views or require more control over the transducer lifecycle.

Both approaches achieve the same functionality—the choice depends on your architectural preferences and specific use case requirements.

> Important: Both `TransducerView` and `ObservableTransducer` work with the exact same `Transducer` or `EffectTransducer` definitions. You can switch between integration approaches without changing your state machine logic at all—the same enum-based transducer can be used in either pattern.

## Counter Transducer Example

Here's the `Counters` transducer that we'll use throughout the SwiftUI integration examples:

```swift
import Oak

enum Counters: Transducer {
    enum State: Terminable {
        case idle(value: Int)
        case finished(value: Int)
        
        var isTerminal: Bool {
            switch self {
            case .finished: return true
            default: return false
            }
        }
        
        var value: Int {
            switch self {
            case .idle(let value), .finished(let value):
                return value
            }
        }
    }
    
    enum Event {
        case intentPlus
        case intentMinus
        case done
    }
    
    static var initialState: State { .idle(value: 0) }
    
    static func update(_ state: inout State, event: Event) {
        switch (state, event) {
        case (.idle(let value), .intentPlus):
            state = .idle(value: value + 1)
        case (.idle(let value), .intentMinus):
            state = .idle(value: value > 0 ? value - 1 : 0)
        case (.idle(let value), .done):
            state = .finished(value: value)
        case (.finished, _):
            break // Terminal state - ignore all events
        }
    }
}
```

This transducer demonstrates several important patterns:
- **Simple state transitions** with immediate updates
- **Terminal state handling** with the `finished` state
- **Computed properties** for convenient state access
- **Value constraints** (count cannot go below 0)

## TransducerView Fundamentals

`TransducerView` is Oak's primary SwiftUI integration component. It manages the transducer lifecycle, handles state updates, and provides event input capabilities.

### Basic Integration

Here's how to connect the `Counters` transducer to a SwiftUI view:

```swift
import SwiftUI
import Oak

struct CounterTransducerView: View {
    @State private var state: Counters.State = .idle(value: 0)

    var body: some View {
        TransducerView(
            of: Counters.self,
            initialState: $state
        ) { state, input in
            VStack(spacing: 20) {
                Text("Count: \(state.value)")
                HStack {
                    Button("➖") { try? input.send(.intentMinus) }
                    Button("➕") { try? input.send(.intentPlus) }
                }
                Button("Done") { try? input.send(.done) }
            }
            .disabled(state.isTerminal)
            .padding()
        }
    }
}
```

The UI is embedded directly in the `TransducerView` closure, where:

- **State access**: The current transducer state is available as a parameter
- **Event sending**: Use `try? input.send(event)` to trigger state transitions
- **State-driven UI**: The interface adapts automatically to state changes (like disabling buttons when in terminal state)

## How TransducerView Works

### State Binding

TransducerView uses a `@State` binding from the parent view. This allows:

- **Parent Observation**: The parent view can react to state changes
- **SwiftUI Integration**: Automatic view updates when state changes
- **Lifecycle Management**: State persists across view updates

### Event Input

The `input` parameter in the view closure provides a way to send events to the transducer:

```swift
try? input.send(.intentPlus)
```

Events are processed synchronously and trigger immediate state transitions.

### Automatic Lifecycle

TransducerView handles:

- **Startup**: Automatically starts the transducer when the view appears
- **Updates**: Triggers view redraws when state changes
- **Cleanup**: Cancels ongoing effects when the view disappears

## State-Driven UI

Oak encourages state-driven UI design where view appearance is determined entirely by current state:

```swift
VStack(spacing: 20) {
    Text("Count: \(state.value)")
    HStack {
        Button("➖") { try? input.send(.intentMinus) }
        Button("➕") { try? input.send(.intentPlus) }
    }
    Button("Done") { try? input.send(.done) }
}
.disabled(state.isTerminal) // Entire UI disabled when finished
```

This approach eliminates the need for separate loading flags or error states since they're encoded in the state machine. When the counter reaches the `finished` state, the entire interface is automatically disabled.

## Parent-Child Communication

TransducerView supports state observation through the binding. Parent views can react to state changes:

```swift
struct ParentView: View {
    @State private var counterState: Counters.State = .idle(value: 0)
    
    var body: some View {
        VStack {
            Text("Current value: \(counterState.value)")
                .font(.headline)
            
            if counterState.isTerminal {
                Text("Counter is finished!")
                    .foregroundColor(.green)
            }
            
            TransducerView(
                of: Counters.self,
                initialState: $counterState
            ) { state, input in
                VStack(spacing: 20) {
                    Text("Count: \(state.value)")
                    HStack {
                        Button("➖") { try? input.send(.intentMinus) }
                        Button("➕") { try? input.send(.intentPlus) }
                    }
                    Button("Done") { try? input.send(.done) }
                }
                .disabled(state.isTerminal)
                .padding()
            }
        }
    }
}
```

## Error Handling

TransducerView provides error handling for event sending:

```swift
Button("➕") {
    do {
        try input.send(.intentPlus)
    } catch {
        // Handle event sending errors
        print("Failed to send event: \(error)")
    }
}
```

In practice, event sending rarely fails unless the transducer is in a terminal state or has been cancelled.

## ObservableTransducer Usage

While `TransducerView` is recommended for most cases, `ObservableTransducer` is useful when you need a view-model pattern or want to share transducer state across multiple views.

### When to Use ObservableTransducer

Consider `ObservableTransducer` when you need:

- **Shared state** across multiple views in a navigation hierarchy
- **Explicit lifecycle control** over when the transducer starts and stops
- **Traditional MVVM patterns** where the view-model is a separate, observable object
- **Complex view hierarchies** where passing bindings becomes cumbersome

### Basic ObservableTransducer Usage

```swift
import SwiftUI
import Oak

struct CounterModelView: View {
    typealias CounterModel = ObservableTransducer<Counters>
    @State var model = CounterModel(initialState: .idle(value: 0))
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Count: \(model.state.value)")
            HStack {
                Button("➖") { try? model.proxy.send(.intentMinus) }
                Button("➕") { try? model.proxy.send(.intentPlus) }
            }
            Button("Done") { try? model.proxy.send(.done) }
        }
        .disabled(model.state.isTerminal)
        .padding()
    }
}
```

### Shared State Example

ObservableTransducer excels when you need to share state between views:

```swift
struct SharedCounterApp: View {
    typealias CounterModel = ObservableTransducer<Counters>
    @State private var counterModel = CounterModel(initialState: .idle(value: 0))
    
    var body: some View {
        NavigationView {
            VStack {
                CounterDisplayView(model: counterModel)
                
                NavigationLink("Edit Counter") {
                    CounterEditView(model: counterModel)
                }
            }
        }
    }
}

struct CounterDisplayView: View {
    let model: ObservableTransducer<Counters>
    
    var body: some View {
        Text("Current Count: \(model.state.value)")
            .font(.title2)
    }
}

struct CounterEditView: View {
    let model: ObservableTransducer<Counters>
    
    var body: some View {
        VStack {
            Text("Edit Count: \(model.state.value)")
            
            HStack {
                Button("➖") { try? model.proxy.send(.intentMinus) }
                Button("➕") { try? model.proxy.send(.intentPlus) }
            }
        }
    }
}
```

### ObservableTransducer vs TransducerView

| Aspect | TransducerView | ObservableTransducer |
|--------|----------------|---------------------|
| **Setup Complexity** | Minimal | Requires view-model class |
| **State Sharing** | Via parent binding | Natural across views |
| **Lifecycle Control** | Automatic | Manual start/stop |
| **SwiftUI Integration** | Native view | Observable object |
| **Recommended Usage** | Most cases | Shared state, MVVM patterns |

## What's Next

This covers both SwiftUI integration approaches. For handling asynchronous operations like network requests, see <doc:Effects>. For more complex patterns and examples, see <doc:Common-Patterns>.