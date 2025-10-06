import SwiftUI
import Oak

enum Sample {}

// MARK: - Transducer

extension Sample: Transducer {
    
    enum State: Terminable {
        case start
        case idle(count: Int)
        case finished(count: Int)
        
        var isTerminal: Bool {
            if case .finished = self { return true }
            return false
        }
    }
    
    enum Event {
        case start
        case stop
        case increment
        case decrement
    }
    
    static func update(_ state: inout State, event: Event) {
        switch (state, event) {
        case (.start, .start):
            state = .idle(count: 0)
        case (.start, _):
            break
        case (.idle(let count), .increment):
            state = .idle(count: count + 1)
        case (.idle(let count), .decrement):
            state = .idle(count: count - 1)
        case (.idle(let count), .stop):
            state = .finished(count: count)
        case (.finished, _):
            break
        case (.idle(count: _), .start):
            state = .idle(count: 0)
        }
    }
    
}

// MARK: - Views
extension Sample { enum Views {} }

extension Sample.State: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .start: return "Start"
        case .idle(count: let count): return "\(count)"
        case .finished: return "Finished"
        }
    }
}

extension Sample.Views {
    
    struct ContentView: View {
        @State var state: Sample.State = .start
        
        var body: some View {
            TransducerView(
                of: Sample.self,
                initialState: $state,
                proxy: Sample.Proxy(initialEvent: .start)
            ) { state, input in
                VStack {
                    Text(verbatim: "state: \(state)")
                        .padding()
                    
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
}

// MARK: - Previews
#Preview {
    Sample.Views.ContentView()
        .padding()
}
