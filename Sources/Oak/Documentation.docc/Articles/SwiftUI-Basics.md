# SwiftUI Integration Basics

Oak provides two primary ways to integrate state machines with SwiftUI: `TransducerView` for declarative view composition and `ObservableTransducer` for view-model patterns.

## Integration Options

Oak offers two approaches for SwiftUI integration:

**`TransducerView`** (Recommended): A SwiftUI view that directly embeds your transducer, managing its lifecycle automatically. Best for most use cases where you want declarative, reactive UI updates.

**`ObservableTransducer`**: An `@Observable` class that wraps your transducer for view-model patterns. Useful when you need to share state across multiple views or require more control over the transducer lifecycle.

Both approaches achieve the same functionality—the choice depends on your architectural preferences and specific use case requirements.

> Important: Both `TransducerView` and `ObservableTransducer` work with the exact same `Transducer` or `EffectTransducer` definitions. You can switch between integration approaches without changing your state machine logic at all—the same enum-based transducer can be used in either pattern.

## Counter Transducer Example

Here's the `Counter` transducer that we'll use throughout the SwiftUI integration examples:

```swift
import Oak

enum Counter: Transducer {
    enum State: Terminable {
        case idle(count: Int)
        case incrementing(count: Int)
        case decrementing(count: Int)
        case finished(count: Int)
        
        var isTerminal: Bool {
            if case .finished = self { return true }
            return false
        }
        
        var count: Int {
            switch self {
            case .idle(let count), .incrementing(let count), 
                 .decrementing(let count), .finished(let count):
                return count
            }
        }
    }
    
    enum Event {
        case increment
        case decrement
        case incrementComplete
        case decrementComplete
        case done
    }
    
    static var initialState: State { .idle(count: 0) }
    
    static func update(_ state: inout State, event: Event) {
        switch (state, event) {
        case (.idle(let count), .increment):
            state = .incrementing(count: count)
        case (.incrementing(let count), .incrementComplete):
            state = .idle(count: count + 1)
        case (.idle(let count), .decrement):
            state = .decrementing(count: count)
        case (.decrementing(let count), .decrementComplete):
            state = .idle(count: max(0, count - 1))
        case (.idle(let count), .done):
            state = .finished(count: count)
        case (.finished, _):
            break // Terminal state - ignore all events
        }
    }
}

extension Counter.State {
    var canIncrement: Bool {
        if case .idle = self { return true }
        return false
    }
    
    var canDecrement: Bool {
        if case .idle = self { return true }
        return false
    }
}
```

This transducer demonstrates several important patterns:
- **Intermediate states** for async operations (`incrementing`, `decrementing`)
- **Terminal state handling** with the `finished` state
- **Computed properties** for convenient state access
- **Helper extensions** for UI logic

## TransducerView Fundamentals

`TransducerView` is Oak's primary SwiftUI integration component. It manages the transducer lifecycle, handles state updates, and provides event input capabilities.

### Basic Integration

Here's how to connect the `Counter` transducer to a SwiftUI view:

```swift
import SwiftUI
import Oak

struct CounterView: View {
    @State private var counterState = Counter.initialState
    
    var body: some View {
        TransducerView(
            of: Counter.self,
            initialState: $counterState
        ) { state, input in
            CounterContentView(state: state, input: input)
        }
    }
}
```

Below is the shared UI component used by both integration approaches:

```swift
struct CounterContentView: View {
    let state: Counter.State
    let sendEvent: (Counter.Event) -> Void
    
    init(state: Counter.State, input: some Subject<Counter.Event>) {
        self.state = state
        self.sendEvent = { event in
            try? input.send(event)
            // Simulate async completion for increment/decrement
            if event == .increment || event == .decrement {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let completionEvent: Counter.Event = event == .increment ? .incrementComplete : .decrementComplete
                    try? input.send(completionEvent)
                }
            }
        }
    }
    
    init(state: Counter.State, sendEvent: @escaping (Counter.Event) -> Void) {
        self.state = state
        self.sendEvent = sendEvent
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Count: \(state.count)")
                .font(.title)
            
            HStack(spacing: 15) {
                Button("Increment") {
                    sendEvent(.increment)
                }
                .disabled(!state.canIncrement)
                
                Button("Decrement") {
                    sendEvent(.decrement)
                }
                .disabled(!state.canDecrement)
                
                Button("Done") {
                    sendEvent(.done)
                }
                .disabled(state.isTerminal)
            }
        }
        .padding()
    }
}
```

> Note: Both integration approaches use the same `CounterContentView` for rendering, demonstrating that the UI logic remains identical regardless of how you integrate the transducer with SwiftUI.

## How TransducerView Works

### State Binding

TransducerView uses a `@State` binding from the parent view. This allows:

- **Parent Observation**: The parent view can react to state changes
- **SwiftUI Integration**: Automatic view updates when state changes
- **Lifecycle Management**: State persists across view updates

### Event Input

The `input` parameter in the view closure provides a way to send events to the transducer:

```swift
try? input.send(.increment)
```

Events are processed asynchronously and may trigger state transitions.

### Automatic Lifecycle

TransducerView handles:

- **Startup**: Automatically starts the transducer when the view appears
- **Updates**: Triggers view redraws when state changes
- **Cleanup**: Cancels ongoing effects when the view disappears

## State-Driven UI

Oak encourages state-driven UI design where view appearance is determined entirely by current state:

```swift
VStack {
    switch state {
    case .idle(let count):
        Text("Ready: \(count)")
            .foregroundColor(.primary)
        
    case .incrementing(let count):
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Adding... \(count)")
        }
        .foregroundColor(.blue)
        
    case .decrementing(let count):
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Subtracting... \(count)")
        }
        .foregroundColor(.orange)
    }
}
```

This approach eliminates the need for separate loading flags or error states since they're encoded in the state machine.

## Parent-Child Communication

TransducerView supports output handling for communication with parent views:

```swift
struct ParentView: View {
    @State private var counterState = Counter.initialState
    @State private var message = "Waiting for updates..."
    
    var body: some View {
        VStack {
            Text(message)
                .padding()
            
            TransducerView(
                of: Counter.self,
                initialState: $counterState
            ) { state, input in
                // Counter UI here
                CounterContent(state: state, input: input)
            } output: { count in
                message = "Counter updated to: \(count)"
            }
        }
    }
}
```

## Error Handling

TransducerView provides error handling for event sending:

```swift
Button("Increment") {
    do {
        try input.send(.increment)
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

@available(iOS 17.0, macOS 14.0, *)
struct CounterWithObservableTransducer: View {
    @State private var model = ObservableTransducer<Counter>(
        initialState: Counter.initialState
    )
    
    var body: some View {
        CounterContentView(state: model.state, sendEvent: model.proxy.send)
    }
}
```

### Shared State Example

ObservableTransducer excels when you need to share state between views:

```swift
@available(iOS 17.0, macOS 14.0, *)
struct SharedCounterApp: View {
    @State private var counterModel = ObservableTransducer<Counter>(
        initialState: Counter.initialState
    )
    
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
    let model: ObservableTransducer<Counter>
    
    var body: some View {
        Text("Current Count: \(model.state.count)")
            .font(.title2)
    }
}

struct CounterEditView: View {
    let model: ObservableTransducer<Counter>
    
    var body: some View {
        VStack {
            Text("Edit Count: \(model.state.count)")
            
            HStack {
                Button("➖") { try? model.proxy.send(.decrement) }
                Button("➕") { try? model.proxy.send(.increment) }
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