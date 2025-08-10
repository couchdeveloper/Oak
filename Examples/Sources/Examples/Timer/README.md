# Timer Effect Example

This example demonstrates how to implement a simple timer effect using Oak's transducer pattern. It showcases a fundamental pattern for handling time-based operations with proper lifecycle management.

## What This Example Shows

- Creating and managing a timer effect with Oak's transducer pattern
- Using effect IDs to identify and cancel specific effects
- Implementing a clean UI with SwiftUI that interacts with a transducer
- Proper management of long-running operations

## Timer Implementation

The example uses a simple approach for the timer implementation:

```swift
private static func createTimer() -> Self.Effect {
    Effect(id: "timer") { env, input, isolator in
        while true {
            try await Task.sleep(for: .seconds(1))
            try input.send(.tick)
        }
    }
}
```

#### Error Propagation in Effect Operations

Notice the use of `try input.send(.tick)` inside the effect operation. If sending the event fails, the error will be thrown and propagated to the transducer, which can then handle the failure appropriately. **Within an effect operation, you should never use `try?` to ignore errors**—errors must be allowed to propagate so the transducer can react to them. This is different from UI event handling, where ignoring errors is often acceptable.

### Why This Implementation is Safe

This simple implementation with an infinite loop is safe because:

1. **Managed Tasks**: Oak's transducer system manages the task execution. When the effect is cancelled, the underlying task will be properly cancelled.

2. **Automatic Cancellation**: When a state transition triggers a new effect with the same ID, the previous effect is automatically cancelled.

3. **Resource Cleanup**: The transducer handles all the necessary cleanup when the effect is no longer needed or when the transducer itself is terminated.

4. **Isolation**: The effect operation runs in a properly isolated context, ensuring thread safety.

## Effect Cancellation

Cancelling the timer effect is straightforward:

```swift
private static func cancelTimer() -> Self.Effect {
    .cancelTask("timer")
}
```

By using the same ID ("timer") that was used when creating the effect, we can easily cancel it. This ID-based cancellation system makes it easy to manage multiple effects without complex bookkeeping.

## Sending Events from the View

The example demonstrates how to send events from a SwiftUI view to the transducer:

```swift
Button("Start") {
    try? transducer.proxy.send(.intentStart)
}
```

### Error Handling with `try?`

We use `try?` to simplify error handling in the UI layer:

1. **Pragmatic Error Handling**: In most cases, if sending an event fails, it's due to one of two scenarios:
   - The transducer has been cancelled/terminated (view is being dismissed)
   - The transducer is in a state where it can't process the event

2. **Fault Tolerance**: Using `try?` allows the UI to continue functioning even if an event can't be processed. This creates a more resilient user experience.

3. **Error Propagation**: Any critical errors in the transducer system will propagate through other channels (such as terminating the transducer), so ignoring the specific sending error is generally safe.

4. **Simplicity**: For most applications, detailed error handling for UI events adds complexity without significant benefits.

In production applications with critical requirements, you might want to implement more comprehensive error handling, potentially showing error messages to the user when events can't be processed.

## Integration with SwiftUI

This example uses `ObservableTransducer` to directly integrate the transducer with SwiftUI:

```swift
let transducer: ObservableTransducer<TimerCounter> = .init(
    initialState: .idle(0),
    env: TimerCounter.Env()
)
```

This approach eliminates the need for a separate view model class, simplifying the architecture while maintaining a clean separation between UI and business logic.

## Best Practices Demonstrated

1. **Intent-Based Events**: Events are named with an "intent" prefix (`.intentStart`, `.intentStop`) to clearly distinguish user-initiated actions from system events.

2. **State-Dependent UI**: UI elements are enabled/disabled based on the transducer's state, preventing invalid operations.

3. **Cancellation Handling**: Effects are properly cancelled when they're no longer needed.

4. **Simple State Management**: The state structure is kept simple with just the essential information needed.

5. **Effect Identification**: Effects are given clear IDs for easier management and cancellation.
