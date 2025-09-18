import Oak
import SwiftUI

// Simple, non-terminating counter state machine with
// async effects
enum EffectCounter: EffectTransducer {
    // State holds counter value and tracks operation
    // progress
    struct State: NonTerminal {
        enum Pending {
            case none
            case increment
            case decrement
        }

        var value: Int = 0
        var pending: Pending = .none
        var isPending: Bool { pending != .none }
    }

    static var initialState: State { State() }

    // Dependencies needed by effects
    struct Env: Sendable {
        init() {
            self.serviceIncrement = { try await Task.sleep(for: .seconds(1)) }
            self.serviceDecrement = { try await Task.sleep(for: .seconds(1)) }
        }
        var serviceIncrement: @Sendable () async throws -> Void
        var serviceDecrement: @Sendable () async throws -> Void
    }

    // Events that trigger state transitions
    enum Event {
        case increment
        case decrement
        case reset
        case incrementReady
        case decrementReady
    }

    // Effect for increment: creates an operation effect
    static func incrementEffect() -> Self.Effect {
        Effect { env, input in
            try await env.serviceIncrement()
            try input.send(.incrementReady)
        }
    }

    // Effect for decrement: creates an operation effect
    static func decrementEffect() -> Self.Effect {
        Effect(id: "decrement") { env, input in
            try await env.serviceDecrement()
            try input.send(.decrementReady)
        }
    }

    // Core state transition logic: a pure function that
    // handles events and returns effects
    static func update(
        _ state: inout State,
        event: Event
    ) -> Self.Effect? {

        switch (state.pending, event) {
        case (.none, .increment):
            state.pending = .increment
            return incrementEffect()
        case (.none, .decrement):
            state.pending = .decrement
            return decrementEffect()
        case (.none, .reset):
            state = State(value: 0, pending: .none)
            return nil
        case (.increment, .incrementReady):
            state.value += 1
            state.pending = .none
            return nil
        case (.decrement, .decrementReady):
            state.value -= 1
            state.pending = .none
            return nil
        // Ignore increment/decrement events during
        // pending operation
        case (_, .increment), (_, .decrement):
            return nil
        case (_, .reset):
            state = State(value: 0, pending: .none)
            return nil
        default:
            return nil
        }
    }
}

extension EffectCounter { enum Views {} }

extension EnvironmentValues {
    @Entry var effectCounterEnv: EffectCounter.Env = .init()
}

#if DEBUG

extension EffectCounter.Views {

    typealias Counter = EffectCounter

    struct ContentView: View {
        @State private var state: Counter.State = Counter.initialState
        @Environment(\.effectCounterEnv) var env

        struct CounterView: View {
            let state: Counter.State
            let input: Counter.Input
            var body: some View {
                VStack(spacing: 24) {
                    Text("\(state.value)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring, value: state.value)
                    HStack(spacing: 20) {
                        ControlButton(
                            systemName: "minus.circle.fill",
                            isDisabled: state.isPending,
                            action: { try? input.send(.decrement) }
                        )
                        ControlButton(
                            systemName: "arrow.counterclockwise.circle.fill",
                            isDisabled: false,
                            action: { try? input.send(.reset) }
                        )
                        ControlButton(
                            systemName: "plus.circle.fill",
                            isDisabled: state.isPending,
                            action: { try? input.send(.increment) }
                        )
                    }
                }
                .padding()
                .frame(minWidth: 250)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .shadow(radius: 5)
                )
                .padding()
                .overlay(alignment: .bottom) {
                    OperationStatusIndicator(pending: state.pending)
                        .transition(.opacity)
                        .zIndex(1)  // show on top
                        .opacity(state.isPending ? 1 : 0)
                        .offset(y: 40)
                }

            }
        }

        struct ControlButton: View {
            let systemName: String
            let isDisabled: Bool
            let action: () -> Void
            var body: some View {
                Button(action: action) {
                    Image(systemName: systemName)
                        .font(.system(size: 36))
                        .symbolEffect(.pulse, isActive: !isDisabled)
                        .foregroundStyle(isDisabled ? .secondary : .primary)
                }
                .disabled(isDisabled)
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }

        struct OperationStatusIndicator: View {
            let pending: Counter.State.Pending
            var body: some View {
                VStack {
                    HStack {
                        ProgressView()
                            .controlSize(.regular)
                        Text(text(for: pending))
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .padding(8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(radius: 2)
                    )
                }
            }
            private func text(for pending: Counter.State.Pending) -> String {
                switch pending {
                case .increment:
                    return "Incrementing..."
                case .decrement:
                    return "Decrementing..."
                case .none:
                    return ""
                }
            }
        }

        var body: some View {
            TransducerView(
                of: Counter.self,
                initialState: $state,
                env: env
            ) { state, input in
                CounterView(state: state, input: input)
            }
        }
    }
}

#Preview("Counter View") {
    EffectCounter.Views.ContentView()
}

#endif

extension EffectCounter.Views {

    struct CounterView: View {
        @Environment(\.effectCounterEnv) var env
        @State private var state: EffectCounter.State = EffectCounter.initialState

        var body: some View {
            TransducerView(
                of: EffectCounter.self,
                initialState: $state,
                env: env
            ) { state, input in
                ZStack {
                    VStack {
                        Text(verbatim: "Counter Value: \(state.value)")
                        Button("Increment") {
                            try? input.send(.increment)
                        }
                        .buttonStyle(.bordered)
                        Button("Decrement") {
                            try? input.send(.decrement)
                        }
                        .buttonStyle(.bordered)
                        Button("Reset") {
                            try? input.send(.reset)
                        }
                        .buttonStyle(.bordered)
                    }
                    .disabled(state.isPending)
                    if state.isPending {
                        ProgressView()
                    }
                }
            }
        }
    }

}

#Preview("Simple Counter View") {
    EffectCounter.Views.CounterView()
}
