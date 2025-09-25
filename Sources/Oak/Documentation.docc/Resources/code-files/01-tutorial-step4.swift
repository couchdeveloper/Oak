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
}