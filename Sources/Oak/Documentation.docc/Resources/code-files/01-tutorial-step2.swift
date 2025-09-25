enum SimpleCounter: Transducer {
    enum State: NonTerminal {
        case idle(count: Int)
    }
}