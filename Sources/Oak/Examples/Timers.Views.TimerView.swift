import SwiftUI

extension Timers { enum Views {} }

fileprivate extension Timers.State {
    
    var isStartable: Bool {
        switch self {
        case .start:
            true
        case .terminated, .running:
            false
        }
    }

    var isStopable: Bool {
        switch self {
        case .start, .terminated:
            false
        case .running:
            true
        }
    }
    
    var count: Int? {
        switch self {
        case .start(count: let count), .running(count: let count):
            count
        default:
            nil
        }
    }
    
}


@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Timers.Views {
    
    struct TimerView: View {
        let state: Timers.State
        let send: (Timers.Event) -> Void
        
        var body: some View {
            VStack {
                switch state {
                case .start(count: let count), .running(count: let count):
                    Text("\(count)")
                        .font(.largeTitle)
                        .contentTransition(.numericText())
                        .animation(.default, value: state.count)
                case .terminated:
                    Text("done")
                }
                if !state.isTerminal {
                    let label = state.isStartable ? "Start" : state.isStopable ? "Stop" : "?"
                    let action: Timers.Event? = state.isStartable ? .start : state.isStopable ? .stop : nil
                    if let action = action {
                        Button("\(label)") {
                            self.send(action)
                        }
                    }
                }
            }
            .navigationTitle(Text("Timer"))
        }
    }
}
    
    
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
#Preview("Timer View start") {
    Timers.Views.TimerView(
        state: .init(),
        send: { print($0) }
    )
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
#Preview("Timer View running(3") {
    Timers.Views.TimerView(
        state: .running(count: 3),
        send: { print($0) }
    )
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
#Preview("TransducerView with TimerView") {
    TransducerView(of: Timers.self, env: Timers.Env()) { state, send in
        Timers.Views.TimerView(
            state: state,
            send: send
        )
    }
}
