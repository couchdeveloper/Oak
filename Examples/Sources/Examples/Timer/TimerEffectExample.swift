// Oak - TimerEffectExample.swift
//
// Demonstrates a simple timer effect with Oak's transducer pattern.

import Foundation
import Oak
import SwiftUI

// MARK: - Timer Transducer

enum TimerCounter: EffectTransducer {

    enum State: NonTerminal {
        case idle(Int)
        case running(Int)

        var counter: Int {
            switch self {
            case .idle(let count), .running(let count):
                return count
            }
        }

        var isRunning: Bool {
            switch self {
            case .idle: return false
            case .running: return true
            }
        }
    }

    enum Event {
        case intentStart
        case intentStop
        case intentReset
        case tick
    }

    // Environment (not used in this example)
    struct Env {}

    // Output type (not used in this example)
    typealias Output = Void

    // Update function that handles state transitions and effects
    static func update(_ state: inout State, event: Event) -> Self.Effect? {
        switch (state, event) {
        case (.idle(let count), .intentStart):
            state = .running(count)
            return createTimer()

        case (.running(let count), .intentStop):
            state = .idle(count)
            return cancelTimer()

        case (.running(let count), .tick):
            state = .running(count + 1)
            return nil

        case (_, .intentReset):
            if case .running = state {
                state = .running(0)
            } else {
                state = .idle(0)
            }
            return nil

        default:
            return nil
        }
    }

    // Creates a timer effect
    private static func createTimer() -> Self.Effect {
        Effect(id: "timer") { env, input, isolator in
            // Simplified timer effect - no task needed as transducer manages this operation
            while true {
                try await Task.sleep(for: .seconds(1))
                try input.send(.tick)
            }
        }
    }

    // Effect to cancel timer
    private static func cancelTimer() -> Self.Effect {
        .cancelTask("timer")
    }
}

// MARK: - View

struct TimerEffectExample: View {
    let transducer: ObservableTransducer<TimerCounter> = .init(
        initialState: .idle(0),
        env: TimerCounter.Env()
    )

    var body: some View {
        VStack(spacing: 24) {
            Text("Timer Effect Example")
                .font(.title)
                .padding()

            Text("Counter: \(transducer.state.counter)")
                .font(.system(size: 40, weight: .bold))
                .padding()

            Text(transducer.state.isRunning ? "Running" : "Stopped")
                .foregroundColor(transducer.state.isRunning ? .green : .red)

            HStack(spacing: 20) {
                Button("Start") {
                    try? transducer.proxy.send(.intentStart)
                }
                .disabled(transducer.state.isRunning)
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Stop") {
                    try? transducer.proxy.send(.intentStop)
                }
                .disabled(!transducer.state.isRunning)
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("Reset") {
                    try? transducer.proxy.send(.intentReset)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.05))
    }
}

// MARK: - Preview

#Preview {
    TimerEffectExample()
}
