# Oak - Swift Finite State Machine Library

[![Oak Framework](https://img.shields.io/badge/🌳-Oak%20FSM-oak?color=8B4513)](https://github.com/couchdeveloper/Oak) [![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20macCatalyst-brightgreen.svg)](https://swift.org)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![macOS 12.0+](https://img.shields.io/badge/macOS-12.0%2B-blue.svg)](https://developer.apple.com/macos/)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

A type-safe, asynchronous finite state machine implementation for Swift, with powerful effect handling and SwiftUI integration.

## Development Status

Oak is actively developed and evolving. The library is well-tested and functional, with a stable core API. 

We encourage developers to try Oak, provide feedback, and contribute to its evolution.

## Overview

**What Oak is:**

  - A Swift library for modeling application logic as finite-state machines (transducers).
  - A unidirectional, event-driven, state-and-effect system with strong type safety.
  - Clear separation of pure state transition logic from side effects (via Effects).
  - A composable architecture that integrates with SwiftUI.
  - A runtime that manages async work (managed tasks) and cancellation in a lifecycle-aware manner.

#### An advanced Example: Effect Counter Transducer

The example demonstrates how to define a state machine which uses effects:

<details>
<summary>Show Example</summary>

```swift
import Oak

// Simple, non-terminating counter state machine with 
// async effects
enum EffectCounter: EffectTransducer {
    // State holds counter value and tracks operation 
    // progress
    struct State: NonTerminal {
        enum Pending {
            case none
            case increment
            case decrement
        }    

        var value: Int = 0
        var pending: Pending = .none
        var isPending: Bool { pending != .none }
    }
    
    static var initialState: State { State() }
    
    // Dependencies needed by effects
    struct Env: Sendable {
        init() {
            self.serviceIncrement = { 
                try await Task.sleep(for: .seconds(1)) 
            }
            self.serviceDecrement = { 
                try await Task.sleep(for: .seconds(1)) 
            }
        }
        var serviceIncrement: @Sendable () async throws -> Void
        var serviceDecrement: @Sendable () async throws -> Void
    }
    
    // Events that trigger state transitions
    enum Event {
        case increment
        case decrement
        case reset
        case incrementReady
        case decrementReady
    }
    
    // Effect for increment: creates an operation effect
    static func incrementEffect() -> Self.Effect {
        Effect { env, input in
            try await env.serviceIncrement()
            try input.send(.incrementReady) 
        }       
    }
    
    // Effect for decrement: creates an operation effect
    static func decrementEffect() -> Self.Effect {
        Effect(id: "decrement") { env, input in
            try await env.serviceDecrement()
            try input.send(.decrementReady)
        }
    }
    
    // Core state transition logic: a pure function that 
    // handles events and returns effects
    static func update(
        _ state: inout State, 
        event: Event
    ) -> Self.Effect? {

        switch (state.pending, event) {
        case (.none, .increment):
            state.pending = .increment
            return incrementEffect()
        case (.none, .decrement):
            state.pending = .decrement
            return decrementEffect()
        case (.none, .reset):
            state = State(value: 0, pending: .none)
            return nil
        case (.increment, .incrementReady):
            state.value += 1
            state.pending = .none
            return nil
        case (.decrement, .decrementReady):
            state.value -= 1
            state.pending = .none
            return nil
            // Ignore increment/decrement events during 
            // pending operation
        case (_, .increment), (_, .decrement):
            return nil
        case (_, .reset):
            state = State(value: 0, pending: .none)
            return nil
        default:
            return nil
        }
    }
}
```

</details>

## Features


- **Type-safety**: Leverage Swift's type system to catch invalid usage at compile time
- **Actor isolation**: Safe execution across different isolation contexts with automatic inference
- **Side effect management**: Structured handling of asynchronous side effects with proper cancellation
- **Environment support**: Provide typed environment to effects for dependencies and configuration
- **Async/await support**: Built on Swift's structured concurrency model
- **SwiftUI integration**: Reactive bindings with `TransducerView`
- **Composability**: Pipe transducer outputs into other transducer inputs
- **Effect composition**: Combine multiple effects sequentially or in parallel
- **Back pressure support**: In compositions, a connected output awaits readiness of the consumer
- **Completion callbacks**: Handle transducer completion with type-safe callbacks

## SwiftUI Integration

### TransducerView

`TransducerView` is a SwiftUI view that integrates transducers directly into your view hierarchy. It manages the transducer's lifecycle, automatically starting it when the view appears and cleaning up when the view disappears. The view reactively updates whenever the transducer's state changes. A `TransducerView` directly uses a view's `@State` as the transducer's state and utilizes SwiftUI's built-in diffing facility for efficient updates. 

As a **Transducer Actor**, `TransducerView` combines the power of transducers with effect handling and the composability of SwiftUI views, enabling hierarchical transducer architectures where parent and child views can each manage their own state machines while participating in a coordinated view hierarchy.


> Note: `TransducerView` can replace conventional ViewModel implementations using `ObservableObject` or the Observation framework. This supports a **"View only architecture"** where traditional artifacts like Model, ViewModel, Router, and Interactor are consolidated and implemented directly as SwiftUI views.


#### Basic Usage

```swift
struct CounterView: View {
    @State private var state = SimpleCounter.State()
    
    var body: some View {
        TransducerView(
            of: SimpleCounter.self,
            initialState: $state
        ) { state, input in
            VStack {
                Text("Count: \(state.count)")
                Button("Increment") { 
                    try? input.send(.increment) 
                }
                Button("Decrement") { 
                    try? input.send(.decrement) 
                }
            }
        }
    }
}
```

#### With Output Handling and Environment for Effects

<details>
<summary>Show Example</summary>

```swift

extension EnvironmentValues {
    @Entry var effectCounterEnv: EffectCounter.Env = .init()
}   

struct ContentView: View {
    @Environment(\.effectCounterEnv) var env
    @State private var state = EffectCounter.initialState
    @State private var lastOutput: String = ""
    
    var body: some View {
        TransducerView(
            of: EffectCounter.self,
            initialState: $state,
            env: env,
            output: Callback { output in
                lastOutput = "Last action: \(output)"
            }
        ) { state, input in
            VStack {
                Text("Count: \(state.count)")
                Text(lastOutput)
                Button("Increment") { try? input.send(.increment) }
            }
        }
    }
}
```
</details>


#### Completion Callbacks

<details>
<summary>Show Example</summary>
Handle transducer completion with type-safe callbacks that are called when the transducer finishes:

```swift
struct ContentView: View {
    @SwiftUI.State private var state = MyTransducer.State()

    var body: some View {
        TransducerView(
            of: MyTransducer.self,
            initialState: $state,
            completion: { result in
                switch result {
                case .success(let output):
                    print("Transducer completed successfully with output: \(output)")
                case .failure(let error):
                    print("Transducer failed with error: \(error)")
                }
            }
        ) { state, input in
            // UI content
        }
    }
}
```

> **Note**: Completion callbacks are always invoked when the transducer finishes, whether it completes successfully or encounters an error. The callback receives a `Result` that contains either the success value or the error.

</details>

### ObservableTransducer

`ObservableTransducer` is an `@Observable` class that wraps a transducer for use outside of SwiftUI views or when you need to share transducer state across multiple views. It provides reactive state management using the Observation framework, making it perfect for ViewModels or standalone state management.

#### Direct Usage in SwiftUI

All you need to do to support this pattern is to instantiate the Observable from the generic type `ObservableTransducer` and assign it a property in the view. You don't need to create the Observable class yourself anymore.

```swift
struct CounterView: View {
    @State private var counter = ObservableTransducer(
        of: CounterTransducer.self,
        initialState: CounterTransducer.State(),
        env: CounterTransducer.Env()
    )
    
    var body: some View {
        VStack {
            Text("Count: \(counter.state.count)")
            Button("Increment") { 
                try? counter.proxy.send(.increment) 
            }
            Button("Decrement") { 
                try? counter.proxy.send(.decrement) 
            }
        }
    }
}
```

> Note: The same Transducer definition, that is a type conforming to either `Transducer` or `EffectTransducer`, can be used for a `TransducerView` and/or for an `ObservableTransducer`.

### Transducer Composition

Oak includes experimental support for composing transducers at the type level. This advanced feature allows for the creation of composite state machines that maintain the type-safety guarantees of the component transducers.

This composition mechanism is still evolving, but it shows promise for building complex state management solutions with clean architectural boundaries. Various composition strategies (parallel, sequential, custom) are being explored to determine the most effective patterns for different use cases.


## Installation

### Swift Package Manager

In Xcode, select **File → Add Packages…** and enter:
```
https://github.com/couchdeveloper/Oak.git
```

Or add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/couchdeveloper/Oak.git", from: "0.28.0")
]
```

## Quick Start

Oak uses **transducers** - finite state machines that process events and produce outputs. Here's how to create a simple counter transducer returning the counter's value as its output:

### 1. Define Your Transducer

```swift
import Oak

// A basic counter transducer that outputs the current count.
enum SimpleCounter: Transducer {
    
    struct State: NonTerminal {
        var count: Int = 0
    }
    
    static var initialState: State { State() }

    enum Event {
        case increment
        case decrement
    }

    enum Output {
        case none
        case value(Int)
    }
    
    static func update(_ state: inout State, event: Event) -> Output {
        switch event {
        case .increment:
            state.count += 1
            return .value(state.count)
        case .decrement:
            state.count -= 1
            return .value(state.count)
        }
    }
}

```


### 2. Run Your Transducer

```swift
let proxy = SimpleCounter.Proxy()

let task = Task {
    try await SimpleCounter.run(
        initialState: SimpleCounter.initialState,
        proxy: proxy
    )
}

// Send events
try proxy.send(.increment)
try proxy.send(.decrement)
```

### 3. Use in SwiftUI

To demonstrate the usage in SwiftUI, the counter transducer will be used using a `TransducerView`. The `TransducerView` has a `Content` view which receives the 
current state and an "Input" for the transducer. The content view is responsible to render the state and send user intents to the transducer via the `input`.

In addition, the counter value can be optionally observed with a `Callback` which calls a closure that receives the current counter value:

```swift
import SwiftUI

struct ContentView: View {
    @SwiftUI.State private var state = SimpleCounter.initialState
    
    var body: some View {
        TransducerView(
            of: SimpleCounter.self,
            initialState: $state,
            output: Callback { output in
                switch output {
                case .none:
                    break
                case .value(let count):
                    print("Count updated to: \(count)")
                }
            }
        ) { state, input in
            VStack {
                Text("Count: \(state.count)")
                Button("Increment") { 
                    try? input.send(.increment) 
                }
                Button("Decrement") { 
                    try? input.send(.decrement) 
                }
            }
        }
    }
}
```
This design allows the enclosing view, that is the `ContentView` in this example, to observe the output and also the transducer's state to react on it. It also allows the ContentView to orchestrate more than one transducer views in more complex scenarios. 

If orchestrating becomes more complex, the `ContentView` may itself utilize a transducer that handles the state transitions and it will become the content view of it. That way, complex hierarchies can be built to solve complex UI scenarios.

Ready for more? Check out the [Core Concepts](#core-concepts) section below!

## Core Concepts

### Transducer
A finite state machine that processes events and produces outputs with optional side effects.

Transducers are implemented as async throwing functions rather than classes with mutable state. This design enables better composability since functions can be composed more easily than objects, and eliminates the need for object lifecycle management.

### Proxy
A proxy provides an asynchronous event channel for sending events to the transducer and letting the transducer obtain these events in an async loop. A proxy is required to start a transducer:

```swift
let proxy = CounterTransducer.Proxy()
try await CounterTransducer.run(
    initialState: CounterTransducer.initialState,
    proxy: proxy
)
```

It can also be used to send events and to forcibly cancel the transducer:

```swift
try proxy.send(.increment)
proxy.cancel()
```

### State
The state of the finite state machine must conform to `Terminable`.

A transducer can run with strictly encapsulated state or with shared state defined in an actor. For strictly encapsulated state, the initial state value is passed to the `run` function. If the state is shared, a binding is used, allowing external components to observe state changes.

```swift
struct State: Terminable {
    var value: Int = 0
    var isTerminal: Bool { value > 10 }
}
```

For non-terminal states, conform to `NonTerminal`:
```swift
struct State: NonTerminal {
    var value: Int = 0
}
```


### Event
Input values that trigger state transitions in the finite state machine.

Events represent things that happen in your system - user actions, network responses, timer events, etc. They are processed by the transducer's `update` function to produce state changes and effects.

```swift
enum Event {
    case userTapped
    case dataReceived(Data)
    case timeout
}
```

### Input

Represents the input channel of a transducer. A proxy has an `input` property which provides access to the transducer's input channel.

An input is used to send events into the transducer. It's passed as a parameter to effect operations and can be shared with other components. Components that only have access to the input interface cannot forcibly cancel the transducer.

```swift
Effect(isolatedOperation: { _, input, _ in
    try await Task.sleep(nanoseconds: 1_000_000_000)
    try input.send(.ready)
})
```

### Output
Values produced by the transducer's update function that can be observed externally, enabling communication with other components or UI updates.

```swift
typealias Output = Int
static func update(_ state: inout State, event: Event) -> Output {
    state.counter += 1
    return state.counter // Output value
}
```

### Effect
An effect is a special output of an effect transducer. It encapsulates an asynchronous operation that can perform side effects and send events back to the transducer.

```swift
typealias Env {}
static func update(_ state: inout State, event: Event) -> Self.Effect? {
   // return an effect or nil
}
```

Effects come in two forms:
- **Actions**: Synchronous functions that return events immediately 
- **Operations**: Long-running, cancellable tasks that send events asynchronously

**Action Effect:**

```swift
static func createDelegate(param: Param) -> Effect {
    let delegate = MyDelegate(param: param)
    return .event(.delegate(delegate))
}
```

**Operation Effect:**

```swift
static func incrementEffect() -> Effect {
    Effect(isolatedOperation: { _, input, _ in
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try input.send(.incrementReady)
    })
}
```

For global actor isolation:

```swift
static func incrementEffect() -> Effect {
    Effect(operation: { @MyGlobalActor _, input in
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try input.send(.incrementReady)
    })
}
```

### Subject
A component that receives output values from a transducer, enabling communication with other parts of your application.

```swift
let output = Callback<Int> { value in
    print("Received output: \(value)")
}

try await CounterTransducer.run(
    initialState: state,
    proxy: proxy,
    output: output
)
```

## Basic Usage

```swift
// Create a proxy and run the transducer
let proxy = CounterTransducer.Proxy()

let task = Task {
    try await CounterTransducer.run(
        initialState: CounterTransducer.State(),
        proxy: proxy,
        env: CounterTransducer.Env()
    )
}

// Send events to the transducer
try proxy.send(.increment)
try proxy.send(.reset)
```

## SwiftUI Integration

```swift
import SwiftUI

extension EnvironmentValues {
    @Entry var effectCounterEnv: EffectCounter.Env = .init()
}   

struct EffectCounterView: View {
    @Environment(\.effectCounterEnv) var env
    @State private var state: EffectCounter.State = EffectCounter.initialState

    var body: some View {
        TransducerView(
            of: EffectCounter.self,
            initialState: $state,
            env: env
        ) { state, input in
            ZStack {
                VStack {
                    Text(verbatim: "Counter Value: \(state.value)")
                    Button("Increment") { 
                        try? input.send(.increment) 
                    }
                    .buttonStyle(.bordered)
                    Button("Decrement") { 
                        try? input.send(.decrement) 
                    }
                    .buttonStyle(.bordered)
                    Button("Reset") { 
                        try? input.send(.reset) 
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(state.isPending)
                if state.isPending {
                    ProgressView()
                }
            }
        }
    }
}
```

<details>
<summary>Counter Transducer Implementation</summary>

```swift
enum CounterTransducer: EffectTransducer {
    
    struct Env {
        var increment: @Sendable () async throws -> Void = {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        var decrement: @Sendable () async throws -> Void = {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
    
    struct State: Terminable {
        var value: Int = 0
        var pending: Pending = .none
        var isTerminal: Bool { false }
        var isPending: Bool { pending != .none }
    }
    
    static var initialState: State { State() }
        
    enum Event {
        case increment
        case decrement
        case reset
        case incrementReady
        case decrementReady
    }
    
    enum Pending {
        case none
        case increment
        case decrement
    }
    
    // Effect for increment: creates an operation effect
    static func incrementEffect() -> Self.Effect {
        Effect(
            operation: { env, input in
                try await env.increment()
                try input.send(.incrementReady)
            }
        )
    }
    
    // Effect for decrement: creates an operation effect
    static func decrementEffect() -> Self.Effect {
        Effect(
            operation: { env, input in
                try await env.decrement()
                try input.send(.decrementReady)
            }
        )
    }
    
    static func update(
        _ state: inout State, 
        event: Event
    ) ->  Self.Effect? {
        switch (state.pending, event) {
        case (.none, .increment):
            state.pending = .increment
            return incrementEffect()
        case (.none, .decrement):
            state.pending = .decrement
            return decrementEffect()
        case (.none, .reset):
            state = State(value: 0, pending: .none)
            return nil
        case (.increment, .incrementReady):
            state.value += 1
            state.pending = .none
            return nil
        case (.decrement, .decrementReady):
            state.value -= 1
            state.pending = .none
            return nil
            // Ignore increment/decrement events during 
            // pending operation
        case (_, .increment), (_, .decrement):
            return nil
        case (_, .reset):
            state = State(value: 0, pending: .none)
            return nil
        default:
            return nil
        }
    }
}
```
</details>

## Design Philosophy

Oak makes state management explicit, predictable, and ergonomic while embracing Swift's modern concurrency features.

## License

Apache License (v2.0) - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
