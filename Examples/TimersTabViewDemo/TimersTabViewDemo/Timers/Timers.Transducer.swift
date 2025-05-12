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

    /// Implements a timer in a very effective way. Due to the Oak transducer
    /// wrapping an async function into a Swift Task and then managing it,
    /// it becomes possible to control the liftetime of the timer, via sending
    /// special events to the transducer. That is, a timer not only ca be started
    /// it also can be cancelled ("invalidated") at any time, by the user for
    /// example. This is achieved by the transducer through cancelling the
    /// wrapping Swift Task. This requires though, that the running operation
    /// (here `Task.sleep(nanoseconds:)` is a good citizen of Swift
    /// Conurrency, and stops running when its task has been cancelled.
    /// Well, this is the case with a library function, so this will work.
    static let timer = Effect(id: "timer") { env, proxy in
        while true {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try? proxy.send(.ping)
        }
    }
}

