# Counter Example

A standalone Xcode project demonstrating Oak's core transducer concepts through a simple counter implementation.

## Overview

This example showcases two approaches to integrating Oak with SwiftUI:

1. **TransducerView**: Oak's recommended SwiftUI integration using direct view embedding
2. **ObservableTransducer**: A view-model pattern for cases requiring shared state across views

## Features Demonstrated

- **Basic state machine**: Simple counter with increment, decrement, and finish states
- **Terminal state handling**: Shows how to handle completion and disable UI appropriately
- **Event-driven updates**: Pure state transitions triggered by user events
- **SwiftUI integration**: Both TransducerView and ObservableTransducer patterns

## Key Concepts

### State Management
```swift
enum State: Terminable {
    case idle(value: Int)
    case finished(value: Int)
}
```

### Event Handling
```swift
enum Event {
    case intentPlus
    case intentMinus  
    case done
}
```

### Pure Updates
The `update` function handles all state transitions without side effects, making the behavior predictable and testable.

## Building and Running

1. Open `CountersExample.xcodeproj` in Xcode
2. Ensure the Oak package dependency is resolved
3. Build and run on iOS Simulator or device (iOS 15.0+)

## Usage in Documentation

This example serves as a reference implementation for:
- Oak documentation code samples
- Tutorial step-by-step examples
- SwiftUI integration patterns
- Testing approaches for simple transducers