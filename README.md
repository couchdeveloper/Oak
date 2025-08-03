# OAK - Swift Finite State Machine Library

[![Oak Framework](https://img.shields.io/badge/🌳-Oak%20FSM-oak?color=8B4513)](https://github.com/couchdeveloper/Oak) [![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20macCatalyst-brightgreen.svg)](https://swift.org)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![macOS 12.0+](https://img.shields.io/badge/macOS-12.0%2B-blue.svg)](https://developer.apple.com/macos/)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)



A type-safe, asynchronous finite state machine implementation for Swift, with powerful effect handling and SwiftUI integration.

## 🚧 Development Status

**Oak is currently in early development** and is actively evolving. While the library is well-tested and functional, please consider the following before using it in production:

- **API Stability**: The public API may change between versions as we refine the design.
- **Breaking Changes**: Expect potential breaking changes in minor version updates until v1.0.
- **Documentation**: API documentation and guides are continuously being improved.
- **Community**: We're building the ecosystem - your feedback and contributions are highly valued!

**Perfect for:**
- ✅ Prototyping and experimentation
- ✅ Learning finite state machine concepts
- ✅ Contributing to an innovative Swift library
- ✅ Early adoption and providing feedback

**Consider carefully for:**
- ⚠️ Production applications requiring API stability
- ⚠️ Projects with tight deadlines
- ⚠️ Teams needing extensive documentation and tutorials

We encourage developers to try Oak, provide feedback, and contribute to its evolution. Follow the repository for updates and join discussions in Issues!

## Overview

OAK provides a robust implementation of finite state machines (FSM), also known as finite state transducers (FST) for Swift applications. It enables you to model complex state transitions and side effects in a type-safe, testable, and maintainable way.


```swift
// Simple, non-terminating counter state machine with async effects
enum CounterTransducer: EffectTransducer {    
    struct State: NonTerminal {
        var value: Int = 0
        var pending: Pending = .none
        var isPending: Bool { pending != .none }
    }
    
    static var initialState: State { State() }
    
    typealias TransducerOutput = Self.Effect?

    struct Env {}
    
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
                try input.send(.incrementReady)
            }
        )
    }
    
    // Effect for decrement: creates an operation effect
    static func decrementEffect() -> Self.Effect {
        Effect(
            operation: { env, input in
                try input.send(.decrementReady)
            }
        )
    }
    
    static func update(_ state: inout State, event: Event) -> TransducerOutput {
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
            // Ignore increment/decrement events during pending operation
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

## Features

- **Type-safety**: Leverage Swift's type system to catch invalid usage at compile time.
- **Actor isolation**: Safe execution across different isolation contexts with automatic inference.
- **Side effect management**: Structured handling of asynchronous side effects with proper cancellation.
- **Environment support**: Provide typed environment to effects for dependencies and configuration.
- **Async/await support**: Built on Swift's structured concurrency model.

## Advanced Features

- **SwiftUI integration**: Reactive bindings with `TransducerView`.
- **Composability**: Pipe transducer outputs into other transducer inputs.
- **Effect composition**: Combine multiple effects sequentially or in parallel.
- **Supports back pressure:** In compositions, a connected output awaits readiness of the consumer.
- **Completion callbacks**: Handle transducer completion with type-safe callbacks.
- **Optional proxy parameters**: Simplified API with automatic proxy creation.

### TransducerView Enhancements

#### Optional Proxy Parameters
`TransducerView` now supports optional proxy parameters. When no proxy is provided, it automatically creates a default proxy:

```swift
// Simplified - no explicit proxy needed
TransducerView(of: MyTransducer.self, initialState: .initial) { state, input in
    // UI content
}

// Still supported - explicit proxy
TransducerView(of: MyTransducer.self, initialState: .initial, proxy: MyProxy()) { state, input in
    // UI content
}
```

#### Completion Callbacks
Handle transducer completion with type-safe callbacks that are called when the transducer successfully completes:

```swift
TransducerView(
    of: MyTransducer.self,
    initialState: .initial,
    completion: { output in
        print("Transducer completed with output: \(output)")
    }
) { state, input in
    // UI content
}
```

> **Note**: Completion callbacks are only invoked on successful completion. They are not called if the transducer encounters an error or is cancelled.

### TransducerView Architecture

`TransducerView` can replace conventional ViewModel implementations using `ObservableObject` or the Observation framework. It directly uses the view's `@State` as the transducer's state and utilizes SwiftUI's built-in diffing facility for efficient updates.

This supports a **"View only architecture"** where traditional artifacts like Model, ViewModel, Router, and Interactor are consolidated and implemented directly as SwiftUI views.


### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/username/Oak.git", from: "1.0.0")
]
```

## Quick Start

### Install via Swift Package Manager
In Xcode, select **File → Add Packages…** and enter:
```
https://github.com/couchdeveloper/Oak.git
```
or in your `Package.swift`:
```swift
dependencies: [
  .package(url: "https://github.com/couchdeveloper/Oak.git", from: "0.15.0"),
],
targets: [
  .target(name: "MyApp", dependencies: ["Oak"]),
]
```

OAK uses **transducers** - finite state machines that process events and produce outputs. Here's how to create one in just a few steps:

### 1. Define Your Transducer

```swift
import Oak

enum SimpleCounter: EffectTransducer {
    struct State: NonTerminal {
        var count: Int = 0
    }
    
    static var initialState: State { State() }
    typealias TransducerOutput = Self.Effect?
    struct Env {}
    
    enum Event {
        case increment
        case decrement
    }
    
    static func update(_ state: inout State, event: Event) -> TransducerOutput {
        switch event {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        }
        return nil
    }
}
```

### 2. Run Your Transducer

```swift
let proxy = SimpleCounter.Proxy()
let task = Task {
    try await SimpleCounter.run(
        initialState: SimpleCounter.initialState,
        proxy: proxy,
        env: SimpleCounter.Env(),
        output: Callback { count in 
            print("Count updated to: \(count)")
        }
    )
}

// Send events
try proxy.send(.increment)
try proxy.send(.decrement)
```

### 3. Use in SwiftUI

```swift
struct ContentView: View {
    var body: some View {
        TransducerView(
            of: SimpleCounter.self,
            initialState: SimpleCounter.initialState,
            env: SimpleCounter.Env()
        ) { state, input in
            VStack {
                Text("Count: \(state.count)")
                Button("Increment") { try? input.send(.increment) }
                Button("Decrement") { try? input.send(.decrement) }
            }
        }
    }
}
```

> **Note**: The `proxy` parameter is optional. If omitted, `TransducerView` creates a default proxy automatically.

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
The state of the finite state machine that must conform to `Terminable`.

A transducer can be run with strictly encapsulated state or with shared state defined in an actor. For strictly encapsulated state the initial state value needs to be passed to the `run` function. If the state is shared, a binding is used, allowing external components to observe the state changes. In this case, the initial state is the current value when passed to the run function.

```swift
struct State: Terminable {
    var value: Int = 0
    var isTerminal: Bool { value > 10 }
}
```

A shorthand to define a non-terminal state is to conform `State` to `NonTerminal`:
```swift
struct State: NonTerminal {
    var value: Int = 0
}
```
which is equivalent to
```swift
struct State: Terminable {
    var value: Int = 0
    var isTerminal: Bool { false }
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

Represents the input of a proxy and thus the input of a transducer. A proxy has a property `input` which returns the input of the proxy. There's no other way to obtain an Input.

An input is solely used to send events into the transducer. It's passed as a parameter to effect operations, but can be passed freely to other components. Other components only see the input interface. Thus, they cannot forcibly cancel the transducer.

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
An effect is a special kind of an output of an effect transducer. It encapsulates an asynchronous operation or action which can perform side effects and can send events back to the transducer.

```swift
typealias Env {}
static func update(_ state: inout State, event: Event) -> Self.Effect? {
   // return an effect or nil
}
```

Effects come in two forms:
- **Actions**: An async function which returns events synchronously to the system when finished.
- **Operations**: A cancellable, long running task which sends one or more events asynchronously via the `Input` parameter, while the system can process other events.

**Action Effect:**

```swift
static func createDelegate(param: Param) -> Effect {
    let delegate = MyDelegate(param: param)
    return .event(.delegate(delegate))
}
```

**Operation effect:**

Parameter "isolatedOperation" is a closure that will be executed on the isolation where function `run` has been executed. The isolation is provided as the third parameter "systemActor" in the closure. The parameter will rarely be used by implementations of the effect. Its purpose is for the compiler to be able to check the isolation statically and during runtime.

```swift
static func incrementEffect() -> Effect {
    Effect(isolatedOperation: { _, input, _ /*systemActor*/ in
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try input.send(.incrementReady)
    })
}
```

An "operation" is a closure that will be executed either non-isolated or isolated to a global actor.

```swift
static func incrementEffect() -> Effect {
    Effect(operation: {@MyGlobalActor _, input in
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
        env: (),
        output: Callback { value in
            print("Counter value: \(value)")
        }
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
    @Entry var myCounterEnv: CounterTransducer.Env = .init()
}

extension CounterExample.Views {
    
    typealias Counter = CounterTransducer

    struct CounterView: View {
        @Environment(\.myCounterEnv) var env
        
        var body: some View {
            TransducerView(
                of: Counter.self,
                initialState: Counter.initialState,
                env: env
            ) { state, input in
                ZStack {
                    VStack {
                        Text(verbatim: "Counter Value: \(state.value)")
                        Button("Increment") { try? input.send(.increment) }
                            .buttonStyle(.bordered)
                        Button("Decrement") { try? input.send(.decrement) }
                            .buttonStyle(.bordered)
                        Button("Reset") { try? input.send(.reset) }
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
    
    typealias TransducerOutput = Self.Effect?
    
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
    
    static func update(_ state: inout State, event: Event) -> TransducerOutput {
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
            // Ignore increment/decrement events during pending operation
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
