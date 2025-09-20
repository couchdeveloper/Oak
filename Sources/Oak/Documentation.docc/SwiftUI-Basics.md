# SwiftUI Integration Basics

Connect your state machines to SwiftUI views using TransducerView for reactive, lifecycle-aware state management.

## TransducerView Fundamentals

`TransducerView` is Oak's primary SwiftUI integration component. It manages the transducer lifecycle, handles state updates, and provides event input capabilities.

### Basic Integration

Here's how to connect the counter from the previous section to a SwiftUI view:

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
            VStack(spacing: 20) {
                Text("Count: \(state.count)")
                    .font(.title)
                
                HStack(spacing: 15) {
                    Button("Increment") {
                        try? input.send(.increment)
                        // Simulate async completion
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            try? input.send(.incrementComplete)
                        }
                    }
                    .disabled(!state.canIncrement)
                    
                    Button("Decrement") {
                        try? input.send(.decrement)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            try? input.send(.decrementComplete)
                        }
                    }
                    .disabled(!state.canDecrement)
                }
            }
            .padding()
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

## What's Next

This covers basic SwiftUI integration with simple transducers. For handling asynchronous operations like network requests, see <doc:Effects>. For more complex UI patterns, see <doc:Hierarchical-Architecture>.