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
        switch (state, event) {
        case (.idle(let count), .increment):
            let newCount = count + 1
            state = .idle(count: newCount)
            return newCount
            
        case (.idle(let count), .decrement):
            let newCount = max(0, count - 1)
            state = .idle(count: newCount)
            return newCount
            
        default:
            fatalError("Reset case not implemented yet")
        }
    }
}