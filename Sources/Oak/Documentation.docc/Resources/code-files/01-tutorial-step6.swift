enum SimpleCounter: Transducer {
    enum State: NonTerminal {
        case idle(count: Int)
    }
    
    enum Event {
        case increment
        case decrement
        case reset
    }
    
    typealias Output = Int
    
    static var initialState: State {
        .idle(count: 0)
    }
    
    static func update(_ state: inout State, event: Event) -> Output {
        // We'll implement the state transitions here
        fatalError("Not implemented yet")
    }
}