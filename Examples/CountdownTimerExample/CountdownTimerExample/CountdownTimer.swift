import SwiftUI
import Oak

enum CountdownTimer {}

// MARK: - Transducer

extension CountdownTimer: EffectTransducer {
    
    enum State: NonTerminal {
        case start
        case ready(startValue: Int)
        case counting(current: Int, startValue: Int)
        case paused(current: Int, startValue: Int)
        case finished(startValue: Int)
    }
    
    enum Event {
        case start(startValue: Int = 10)
        case intentIncrementStartValue
        case intentDecrementStartValue
        case intentBeginCountdown
        case intentPause
        case intentResume
        case intentCancel
        case intentReset
        case timerTick
    }
        
    struct Env: Sendable {}
    
    static func update(_ state: inout State, event: Event) -> Self.Effect? {
        switch (state, event) {
        case (.start, .start(let startValue)):
            state = .ready(startValue: startValue)
            return nil
            
        case (.ready(let startValue), .intentBeginCountdown):
            state = .counting(current: startValue, startValue: startValue)
            return timerEffect()
            
        case (.ready(let currentValue), .intentIncrementStartValue):
            state = .ready(startValue: currentValue + 1)
            return nil
            
        case (.ready(let currentValue), .intentDecrementStartValue):
            let newValue = max(0, currentValue - 1)
            state = .ready(startValue: newValue)
            return nil
            
        case (.counting(let current, let startValue), .timerTick):
            if current > 1 {
                state = .counting(current: current - 1, startValue: startValue)
                return timerEffect()
            } else {
                state = .finished(startValue: startValue)
                return .cancelTask("countdown")
            }
            
        case (.counting(let current, let startValue), .intentPause):
            state = .paused(current: current, startValue: startValue)
            return .cancelTask("countdown")
            
        case (.paused(let current, let startValue), .intentResume):
            state = .counting(current: current, startValue: startValue)
            return timerEffect()
            
        case (.counting, .intentCancel), (.paused, .intentCancel):
            state = .start
            return .sequence(.cancelTask("countdown"), .event(.start()))
            
        case (.finished, .intentReset):
            state = .start
            return .event(.start())
            
        default:
            print("unexpected state/event combination: \(state)/\(event)")
            return nil
        }
    }
    
    static var initialState: State { .start }
        
    private static func timerEffect() -> Effect {
        Effect(id: "countdown") { env, input in
            try await Task.sleep(for: .seconds(1))
            try input.send(.timerTick)
        }
    }
}

// MARK: - Views

extension CountdownTimer { enum Views {} }

extension CountdownTimer.Views {
    
    public struct ContentView: View {
        @State private var state = CountdownTimer.initialState
        
        public init() {}
        
        public var body: some View {
            TransducerView(
                of: CountdownTimer.self,
                initialState: $state,
                env: CountdownTimer.Env()
            ) {
                state,
                input in
                VStack(spacing: 20) {
                    Text("Countdown Timer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    switch state {
                    case .start:
                        // Temporary loading state - transitions immediately to ready
                        Color.clear
                        
                    case .ready(let startValue):
                        ReadyView(
                            startValue: startValue,
                            input: input
                        )
                        
                    case .counting(let current, let startValue):
                        CountingView(
                            current: current,
                            startValue: startValue,
                            input: input
                        )
                        
                    case .paused(let current, let startValue):
                        PausedView(
                            current: current,
                            startValue: startValue,
                            input: input
                        )
                        
                    case .finished(let startValue):
                        FinishedView(
                            startValue: startValue,
                            input: input
                        )
                    }
                }
                .padding()
                .frame(maxWidth: 400)
                .onAppear {
                    try? input.send(.start())
                }
            }
        }
    }
}
    
// MARK: - Child Views
extension CountdownTimer.Views {
    
    struct ReadyView: View {
        let startValue: Int
        let input: CountdownTimer.Proxy.Input

        var body: some View {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Button("-") {
                        try? input.send(.intentDecrementStartValue)
                    }
                    .buttonStyle(.bordered)
                    .disabled(startValue <= 0)
                    
                    Text("\(startValue)")
                        .font(.system(size: 72, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(minWidth: 120)
                    
                    Button("+") {
                        try? input.send(.intentIncrementStartValue)
                    }
                    .buttonStyle(.bordered)
                }
                
                Text("Ready to start")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Button("Start") {
                    try? input.send(.intentBeginCountdown)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    struct CountingView: View {
        let current: Int
        let startValue: Int
        let input: CountdownTimer.Proxy.Input

        var body: some View {
            VStack(spacing: 16) {
                Text("\(current)")
                    .font(.system(size: 72, weight: .bold, design: .monospaced))
                    .foregroundColor(current <= 3 ? .red : .primary)
                
                Text("Time remaining")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Button("Pause") {
                        try? input.send(.intentPause)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Cancel") {
                        try? input.send(.intentCancel)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    struct PausedView: View {
        let current: Int
        let startValue: Int
        let input: CountdownTimer.Proxy.Input

        var body: some View {
            VStack(spacing: 16) {
                Text("\(current)")
                    .font(.system(size: 72, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                
                Text("Paused")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                HStack(spacing: 16) {
                    Button("Resume") {
                        try? input.send(.intentResume)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Cancel") {
                        try? input.send(.intentCancel)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    struct FinishedView: View {
        let startValue: Int
        let input: CountdownTimer.Proxy.Input

        var body: some View {
            VStack(spacing: 16) {
                Text("0")
                    .font(.system(size: 72, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                
                Text("Time's up!")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Button("Start New Timer") {
                    try? input.send(.intentReset)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
}

// MARK: - Previews

#Preview("ReadyView") {
    @Previewable @State var proxy = CountdownTimer.Proxy()
    
    CountdownTimer.Views.ReadyView(
        startValue: 10,
        input: proxy.input
    )
    .padding()
}

#Preview("CountingView") {
    @Previewable @State var proxy = CountdownTimer.Proxy()
    
    CountdownTimer.Views.CountingView(
        current: 9,
        startValue: 10,
        input: proxy.input
    )
    .padding()
}

#Preview("PausedView") {
    @Previewable @State var proxy = CountdownTimer.Proxy()
    
    CountdownTimer.Views.PausedView(
        current: 3,
        startValue: 10,
        input: proxy.input
    )
    .padding()
}

#Preview("FinshedView") {
    @Previewable @State var proxy = CountdownTimer.Proxy()
    
    CountdownTimer.Views.FinishedView(
        startValue: 10,
        input: proxy.input
    )
    .padding()
}

#Preview {
    CountdownTimer.Views.ContentView()
        .padding()
}
