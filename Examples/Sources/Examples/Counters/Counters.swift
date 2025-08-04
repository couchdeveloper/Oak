import Oak
import Observation
import SwiftUI

enum Counters: Transducer {

    enum State: Terminable {
        case idle(value: Int)
        case finished(value: Int)
        var isTerminal: Bool {
            switch self {
            case .finished: return true
            default: return false
            }
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
            break
        }
    }
}

struct CounterTransducerView: View {
    var body: some View {
        TransducerView(
            of: Counters.self,
            initialState: .idle(value: 0)
        ) { state, input in
            VStack(spacing: 20) {
                Text("Count: \(state.value)")
                HStack {
                    Button("➖") { try? input.send(.intentMinus) }
                    Button("➕") { try? input.send(.intentPlus) }
                }
                Button("Done") { try? input.send(.done) }
            }
            .disabled(state.isTerminal)
            .padding()
        }
    }
}

struct CounterModelView: View {
    typealias CounterModel = ObservableTransducer<Counters>
    @State var model = CounterModel(initialState: .idle(value: 0))
    var body: some View {
        VStack {
            VStack(spacing: 20) {
                Text("Count: \(model.state.value)")
                HStack {
                    Button("➖") { try? model.proxy.send(.intentMinus) }
                    Button("➕") { try? model.proxy.send(.intentPlus) }
                }
                Button("Done") { try? model.proxy.send(.done) }
            }
            .disabled(model.state.isTerminal)
            .padding()
        }
    }
}

#Preview {
    CounterTransducerView()
}

#Preview {
    CounterModelView()
}
