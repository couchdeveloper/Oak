# Countdown Timer Example

A standalone Xcode project demonstrating Oak's advanced EffectTransducer concepts through a comprehensive countdown timer implementation.

## Overview

This example showcases Oak's powerful effect system and demonstrates how to build a real-world application with complex async operations, state management, and user interactions.

## Features Demonstrated

- **EffectTransducer**: Advanced finite state machine with async effect capabilities
- **Timer effects**: Starting, pausing, resuming, and canceling async timer operations
- **Sequence effects**: Chaining multiple effects for cleanup and state transitions
- **State management**: Five-state FSM with proper transitions and validation
- **Interactive UI**: Real-time countdown display with user controls
- **NonTerminal states**: Continuous operation allowing multiple timer cycles

## Key Concepts

### Advanced State Machine
```swift
enum State: NonTerminal {
    case start
    case ready(startValue: Int)
    case counting(current: Int, startValue: Int)
    case paused(current: Int, startValue: Int)
    case finished(startValue: Int)
}
```

### Comprehensive Event Handling
```swift
enum Event {
    case start(startValue: Int = 10)
    case intentIncrementStartValue
    case intentDecrementStartValue
    case beginCountdown
    case tick
    case pause
    case resume
    case cancel
    case reset
}
```

### Effect Management
The example demonstrates three key effect patterns:

#### 1. Timer Effects
```swift
private static func timerEffect() -> Effect {
    Effect(id: "countdown") { env, input in
        try await Task.sleep(for: .seconds(1))
        try input.send(.tick)
    }
}
```

#### 2. Task Cancellation
```swift
case (.counting(let current, let startValue), .pause):
    state = .paused(current: current, startValue: startValue)
    return .cancelTask("countdown")
```

#### 3. Sequence Effects
```swift
case (.counting, .cancel), (.paused, .cancel):
    state = .start
    return .sequence(.cancelTask("countdown"), .event(.start()))
```

The sequence effect is particularly powerful - it ensures proper cleanup (canceling the timer task) followed by state transition (triggering a reset event), demonstrating how to chain operations safely.

## User Interface

The timer provides an intuitive interface:

- **Setup**: Adjust countdown time with "+" and "-" buttons
- **Control**: Start, pause, resume, and cancel operations
- **Feedback**: Visual progress indicator and time-sensitive styling
- **Reset**: Easy restart for multiple timer sessions

## Architecture Highlights

### NonTerminal State Design
Unlike terminal state machines, this example uses `NonTerminal` states allowing continuous operation. Users can run multiple countdown cycles without recreating the transducer.

### Effect Coordination
Demonstrates sophisticated effect management:
- **Task identification**: Named effects ("countdown") for precise control
- **Cleanup patterns**: Proper cancellation before state changes
- **Event sequencing**: Guaranteed order of operations with `.sequence`

### SwiftUI Integration
Shows professional SwiftUI patterns:
- **View struct architecture**: Proper separation of concerns
- **Public API design**: Package-ready structure with namespace organization
- **State-driven UI**: Interface responds to transducer state changes

## Building and Running

1. Open `CountdownTimerExample.xcodeproj` in Xcode
2. Ensure the Oak package dependency is resolved
3. Build and run on iOS Simulator or device (iOS 15.0+)

## Usage in Documentation

This example serves as a reference implementation for:
- EffectTransducer patterns and best practices
- Async timer management with proper cancellation
- Sequence effect usage for complex state transitions
- Real-world SwiftUI integration with Oak
- NonTerminal state machine design