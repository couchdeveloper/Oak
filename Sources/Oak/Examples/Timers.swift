// Example

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
    enum Event {
        case start, stop, ping, terminate
    }
    
    struct Env {}
    
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

    static let timer = Effect(id: "timer") { env, proxy in
        while true {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try? proxy.send(.ping)
        }
    }
}

