import SwiftUI
import Oak

enum Counters {}

// MARK: - Transducer

extension Counters: Transducer {
    
    enum State: Terminable {
        case idle(value: Int)
        case finished(value: Int)
        
        var isTerminal: Bool {
            if case .finished = self { return true }
            return false
        }
        
        var value: Int {
            switch self {
            case .idle(let value), .finished(let value):
                return value
            }
        }
    }
    
    enum Event {
        case intentPlus
        case intentMinus
        case done
    }
    
    static func update(_ state: inout State, event: Event) {
        switch (state, event) {
        case (.idle(let value), .intentPlus):
            state = .idle(value: value + 1)
        case (.idle(let value), .intentMinus):
            state = .idle(value: value > 0 ? value - 1 : 0)
        case (.idle(let value), .done):
            state = .finished(value: value)
        case (.finished, _):
            break // Terminal state - ignore all events
        }
    }
    
}

// MARK: - Views
extension Counters { enum Views {} }

extension Counters.State: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .idle(let value): return "Count: \(value)"
        case .finished(let value): return "Finished: \(value)"
        }
    }
}

extension Counters.Views {
    
    struct ContentView: View {
        @State var state: Counters.State = .idle(value: 0)
        
        var body: some View {
            NavigationView {
                VStack(spacing: 30) {
                    Text("Counter Example")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    TransducerView(
                        of: Counters.self,
                        initialState: $state
                    ) { state, input in
                        VStack(spacing: 20) {
                            Text(verbatim: "State: \(state)")
                                .font(.title2)
                                .padding()
                            
                            HStack(spacing: 20) {
                                Button("➖") {
                                    try? input.send(.intentMinus)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .disabled(state.isTerminal)
                                
                                Button("➕") {
                                    try? input.send(.intentPlus)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .disabled(state.isTerminal)
                            }
                            
                            Button("Done") {
                                try? input.send(.done)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(state.isTerminal)
                        }
                    }
                    
                    if state.isTerminal {
                        Text("Counter is finished!")
                            .font(.headline)
                            .foregroundColor(.green)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .navigationTitle("Counters")
                .frame(minWidth: 300)
            }
        }
    }
}


// MARK: - Previews
#Preview {
    Counters.Views.ContentView()
        .padding()
}
