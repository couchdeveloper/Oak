import Oak
import SwiftUI

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
