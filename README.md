# Oak

Oak brings the power of finite state machines (FSM) to your projects. 

The Oak library is primarily intended to implement the typical frontend patterns and artefacts, like ViewModels, Interactors, etc., but it is not limited to this.


## Overview

Finite State Machines (FSMs) are invaluable tools for managing systems with discrete and sequential behaviours. Their mathematical framework ensures correctness, providing a robust foundation that helps prevent logical errors. One of the key strengths of FSMs is their composability, allowing complex behaviours to be constructed from simpler, well-defined states and transitions.

This makes them an ideal candidate to implement the logic in user interfaces, but they can effectively address a wide range of problems. 

> Tip: Oak state machines seamlessly integrate directly into SwiftUI views, eliminating the need to employ observable classes or utilise the Observation framework. 

The code below provides a basic example of how this functionality can be implemented using Oak. It can be copied and pasted into Xcode Preview and run.

<details>
    <summary>File: `Timers.Transducer.swift`</summary>

```swift
import Oak

/// Defines a FST which can start and stop a timer (a side effect).
/// Only one timer can run at a time. The timer itself sends an
/// event `ping` to the FST which increments a counter variable
/// within the state of the FST.
///
/// An Oak transducer can be run with an _observable_ state.
/// That is, there's a kind of "host" which runs the transducer and
/// provides it its state whose mutations can be observed by the
/// host. A SwiftUI View is a perfect host for running a transducer.
/// Not only can it render the state accordingly, views also provide
/// a natural means to send events into the FSA, i.e. user intents,
/// via UI controls.
///
/// This is a very simple variant of a FST. Yet, it demonstrates one
/// of the key feature of Oak Transducers: the FSM keeps track of
/// the management of running _side effects_. A side effect can be a
/// Swift Task, which emits events during its lifetime, or an async
/// function which may or may not return a result which materialises
/// as an event, or simply a synchronous function which may or
/// may not cause an effect on the "outer world".
///
/// See also ``Oak.Transduder``.
enum Timers: Transducer {
    
    /// The state of the transducer. This is also used as  the "view state".
    enum State: Terminable, DefaultInitializable {
        init() { self = .start(count: 0) }
        
        case start(count: Int = 0)
        case running(count: Int)
        case terminated
        
        var isTerminal: Bool {
            if case .terminated = self { true } else { false }
        }
    }
    
    /// Defines the "Input" values of the transducer.
    ///
    /// Inputs are always _events_, that is, "things" that _happen_.
    /// Events can be _user intents_ and results or messages sent
    /// from side effects, which need to be _materialized_ as events
    /// and send back to the transducer.
    enum Event {
        case start, stop, ping, terminate
    }
    
    /// An _environment_ can be used to provide dependencies for _effects_
    /// when they get invoked and start _side effects_.
    struct Env {}
    
    /// See also: ``Oak.Effect``
    typealias Effect = Oak.Effect<Event, Env>
    
    /// A _pure_ function which implementes the transition function and the output function
    /// of a stransducer. The output is an optioanal `Effect`.
    static func update(_ state: inout State, event: Event) -> Effect? {
        print("*** event: \(event), state: \(state)")
        switch (event, state) {
        case (.start, .start(let count)):
            state = .running(count: count)
            return timer
        case (.start, .running):
            return .none

        case (.stop, .running(let count)):
            state = .start(count: count)
            return .cancelTask("timer")
            
        case (.stop, .start):
            return .none
            
        case (.ping, .running(let count)):
            state = .running(count: count + 1)
            return .none
            
        case (.ping, .start):
            return .none
            
        case (.terminate, .running):
            state = .terminated
            return .cancelTask("timer")

        case (.terminate, .start):
            state = .terminated
            return .none

        case (.terminate, .terminated):
            return .none
            
        case (.ping, .terminated):
            return .none
        case (.stop, .terminated):
            return .none
        case (.start, .terminated):
            return .none
        }
    }

    /// Implements a timer which periodically sends a `ping` event to the
    /// transducer until it will be cancelled.
    ///
    /// The Oak transducer wraps an asynchronous function in a Swift Task and
    /// manages it, allowing you to control the timer's lifetime by sending special
    /// events to the transducer. This means a timer can be started and cancelled
    /// ("invalidated") at any time, for instance, by the user. The transducer
    /// achieves this by cancelling the wrapping Swift Task. However, this
    /// requires the running operation (in this case, `Task.sleep(nanoseconds:)`)
    /// to be a good citizen of Swift Concurrency and stop running when its task
    /// is cancelled. Fortunately, this is the case with a library function, so
    /// it will work.
    static let timer = Effect(id: "timer") { env, proxy in
        while true {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try? proxy.send(.ping)
        }
    }
}
```
</details>

<details>
    <summary>File: `Timers.Views.TimerView`</summary>

```swift
import SwiftUI
import Oak

extension Timers { enum Views {} }

fileprivate extension Timers.State {        
    var isStartable: Bool {
        switch self {
        case .start:
            true
        case .terminated, .running:
            false
        }
    }

    var isStopable: Bool {
        switch self {
        case .start, .terminated:
            false
        case .running:
            true
        }
    }
    
    var count: Int? {
        switch self {
        case .start(count: let count), .running(count: let count):
            count
        default:
            nil
        }
    }        
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Timers.Views {
    
    struct TimerView: View {
        let state: Timers.State
        let send: (Timers.Event) -> Void
        
        var body: some View {
            VStack {
                switch state {
                case .start(count: let count), .running(count: let count):
                    Text("\(count)")
                        .font(.largeTitle)
                        .contentTransition(.numericText()) // Note: `contentTransition` is only available in iOS 16.0 or newer
                        .animation(.default, value: state.count)
                case .terminated:
                    Text("done")
                }
                if !state.isTerminal {
                    let label = state.isStartable ? "Start" : state.isStopable ? "Stop" : "?"
                    let action: Timers.Event? = state.isStartable ? .start : state.isStopable ? .stop : nil
                    if let action = action {
                        Button("\(label)") {
                            self.send(action)
                        }
                    }
                }
            }
            .navigationTitle(Text("Timer"))
        }
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Timers.Views {
    
    struct NavigationStackView: View {
        
        struct Timer: Identifiable, Hashable {
            let id: Int
        }

        @State private var timers: [Timer] = (1...10).map { Timer(id: $0) }
        
        var body: some View {
            NavigationStack {  //
                List(timers) { timer in
                    NavigationLink("\(timer.id)", value: timer)
                }
                .navigationDestination(for: Timer.self) { timer in
                    TransducerView(of: Timers.self, env: Timers.Env()) { state, send in
                        Timers.Views.TimerView(
                            state: state,
                            send: send
                        )
                    }
                    .navigationTitle("Timer \(timer.id)")
                }
            }
        }
    }
    
}

// MARK: - Previews

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
#Preview("Timer View start") {
    Timers.Views.TimerView(
        state: .init(),
        send: { print($0) }
    )
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
#Preview("Timer View running(3)") {
    Timers.Views.TimerView(
        state: .running(count: 3),
        send: { print($0) }
    )
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
#Preview("TransducerView with TimerView") {
    TransducerView(of: Timers.self, env: Timers.Env()) { state, send in
        Timers.Views.TimerView(
            state: state,
            send: send
        )
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
#Preview("Timer List") {
    Timers.Views.NavigationStackView()
}
```
</details>



## Benefits of using State Machines

Applications often suffer from bugs due to incorrect logic, such as issues arising when a method is invoked multiple times before a prior operation completes. FSMs address this by explicitly modelling the state of the system, reducing the likelihood of such errors. For example, in handling network API requests within a view model, an FSM can manage the state of pending requests, ensuring that subsequent calls behave appropriately depending on the current state.

Acknowledging that most computations are inherently stateful, FSMs offer a structured and clear approach to implementing state-dependent logic. By defining explicit states and transitions, they enhance the clarity, maintainability, and reliability of the system.

A state machine aligns well with views that adhere to the "a view is a function of state" principle, like those in SwiftUI, because it can effectively provide the necessary state for the view. This approach also promotes an event-driven and unidirectional model, enhancing clarity and simplifying the process of ensuring correctness. Oak State machines can be directly used in SwiftUI as a View.

Oak emphasises on fundamental principles such as:

- Enhancing static reasonability
- Utilising pure functions
- Adopting an event-driven approach
- Maintaining unidirectional flow
- Prioritising coding styles that promote high _Locality of Behaviour_ (LoB)
- Oak FSM can generate _effects_ as output. An effect is a mechanism for executing side effects, which are asynchronous operations that can be cancelled within the transition function if necessary. Effects can even spawn other state machines, making it a powerful feature which can be used to solve highly complex problems.


## What is a Finite State Machine

Finite State Machines (FSMs) are mathematical models used to represent and control behaviour, particularly in digital logic. Their core principles revolve around a finite set of _states_, _transitions_ between these states based on _inputs_, and potentially _outputs_ that depend on the current state and input. 

### Key Concept of Finite State Machines (FSMs):

1. States: FSMs have a finite number of states, each representing a different condition or situation. A FSM is always in one of these states. A state can carry more complex data, which is called an _extended_ state and the FSM is called an Extended Finite State Machine (EFSM).

2. Transitions: FSMs can move from one state to another based on the current state and the input events. 

3. Inputs: FSMs can receive inputs (events) that trigger transitions between states. These inputs can be simple signals or more complex data.

4. Outputs: Some FSMs can produce outputs based on the current state and input. These outputs can be actions, data, or signals. 

Both the transitions and the outputs of a FSM will be defined as a function.


#### A code snippet in Swift to demonstrate the concept 

Defining the state, input (Event) and the transition function of a FSM: 

```swift 
enum Counter {
    enum State {
        case start
        case idle(counter: Int)
        case terminated(finalValue: Int)
    }
    
    enum Event {
        case start(initialValue: Int)
        case countUp
        case countDown
        case terminate
    }
    
    static func transition(_ state: inout State, event: Event) {
        defer {
            print("event: \(event), state: \(state)")
        }
        switch (event, state) {
        case (.start(let initialValue), .start):
            state = .idle(counter: initialValue)
            return
        case (.countUp, .idle(counter: let counter)):
            state = .idle(counter: counter + 1)
            return
        case (.countDown, .idle(counter: let counter)):
            state = .idle(counter: counter - 1)
            return
        case (.terminate, .idle(counter: let counter)):
            state = .terminated(finalValue: counter)
            return
            
        case (.terminate, .start):
            return
        case (.countDown, .start):
            return
        case (.countUp, .start):
            return
        case (.start, .idle):
            return
        case (_, .terminated):
            return
        }
    }
}
```

Note, that the FSM above does not produce an output, which is optional.

Now, a SwiftUI view can use this in this way:

> Note: This is not how Oak actually implements it. The code below is only to show the basic idea:
 

```swift
import SwiftUI

extension Counter { enum Views {} }

extension Counter.State {
    var counter: Int? {
        switch self {
        case .idle(counter: let value):
            value
        case .terminated(finalValue: let value):
            value
        case .start:
            nil
        }
    }
}

extension Counter.Views {
 
    struct ContentView: View {
        @State private var state: Counter.State = .idle(counter: 0)
        
        var body: some View {
            let counter = state.counter ?? 0
            VStack {
                Text("\(counter)")
                    .font(.largeTitle)
                    .padding()
                
                HStack {
                    Button {
                        send(.countUp)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .padding()
                    Button {
                        send(.countDown)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .padding()
                }
            }
        }
        
        func send(_ event: Counter.Event) {
            Counter.transition(&state, event: event)
        }
    }
}


#Preview {
    Counter.Views.ContentView()
}
``` 

## Quick Start

### Installation

### Usage



## Examples

## Contributing

## Credits

## License
