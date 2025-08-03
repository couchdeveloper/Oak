import Oak
import Testing

/// EffectUsageTests
///
/// This test suite verifies the correct construction, execution, and isolation of effects within transducers.
///
/// The tests cover:
/// - Creation of effects using various initializers (primary, async, action, operation, and event-based).
/// - Correct event handling and state transitions within the transducer.
/// - Proper actor or global actor isolation for effect execution, ensuring thread safety and preventing data
/// races.
/// - Thread-safety of environment mutation, with explicit tests designed to be run under Thread Sanitizer
/// (TSAN).
/// - Handling of actor-isolated environments and payloads.
///
/// These tests ensure that the transducer and effect system works as intended in both synchronous and
/// asynchronous contexts, and that isolation boundaries are respected throughout effect execution.
struct EffectUsageTests {

    // MARK: - Action Effect
    @TestGlobalActor
    @Test
    func createEffectWithActionInitialiser() async throws {

        enum T: EffectTransducer {
            class Env { var value: Int = 0 }
            class Payload { var value: Int = 0 }
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload) }
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    let effect = T.Effect(isolatedAction: { env, isolated in
                        TestGlobalActor.shared.assertIsolated()
                        env.value = 1
                        let payload = T.Payload()
                        return [.payload(payload)]
                    })
                    return effect

                case .payload(let payload):
                    payload.value = 1
                    state = .finished
                    return nil
                }
            }
        }

        let env = T.Env()
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: env)
    }

    @TestGlobalActor
    @Test
    func createEffectWithActionInitialiserAsync() async throws {

        enum T: EffectTransducer {
            class Env { var value: Int = 0 }
            class Payload { var value: Int = 0 }
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload) }
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    let effect = T.Effect(isolatedAction: { env, isolated in
                        isolated.assertIsolated()
                        try await Task.sleep(nanoseconds: 1_000_000)
                        env.value = 1
                        let payload = T.Payload()
                        return [.payload(payload)]
                    })
                    return effect

                case .payload(let payload):
                    payload.value = 1
                    state = .finished
                    return nil
                }
            }
        }

        let env = T.Env()
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: env)
    }

    @TestGlobalActor
    @Test
    func createEffectWithActionInitialiserAccessingIsolatedEnv() async throws {

        enum T: EffectTransducer {
            @MainActor class Env { var value: Int = 0 }
            class Payload { var value: Int = 0 }
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload) }
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    let effect = T.Effect(action: { @MainActor env in
                        try await Task.sleep(nanoseconds: 1_000_000)
                        env.value = 1
                        let payload = T.Payload()
                        return [.payload(payload)]
                    })
                    return effect

                case .payload(let payload):
                    payload.value = 1
                    state = .finished
                    return nil
                }
            }
        }

        let env = T.Env()
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: env)
    }

    @TestGlobalActor
    @Test func testWithMainActorIsolatedEnv() async throws {

        enum T: EffectTransducer {
            @MainActor class Env { var value: Int = 0 }
            class Payload { var value: Int = 0 }
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload) }

            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    return actionEffect()

                case .payload(let payload):
                    payload.value = 1
                    state = .finished
                    return nil
                }
            }

            static func actionEffect() -> T.Effect {
                T.Effect(action: { @MainActor env in
                    try await Task.sleep(nanoseconds: 1_000_000)
                    env.value = 1
                    let payload = T.Payload()
                    return [.payload(payload)]
                })
            }
        }

        let env = T.Env()
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: env)
    }

    // MARK: - Operation Effect
    @MainActor
    @Test
    func createEffectWithIsolatedOperationInitialiser() async throws {

        enum T: EffectTransducer {
            class Env { var value = 0 }
            class Payload { var value: Int = 0 }
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload) }

            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    let effect = T.Effect(
                        id: 1,
                        isolatedOperation: { env, input, isolated in
                            isolated.assertIsolated()
                            env.value = 1
                            try await Task.sleep(nanoseconds: 1_000_000)
                            let payload = T.Payload()
                            try input.send(.payload(payload))
                        })
                    return effect

                case .payload(let payload):
                    payload.value = 1
                    state = .finished
                    return nil
                }
            }
        }

        let env = T.Env()
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: env)
    }

    @MainActor
    @Test
    func createEffectWithOperationWithMainActorIsolatedEnv() async throws {

        enum T: EffectTransducer {
            @MainActor class Env { var value = 0 }
            class Payload { var value: Int = 0 }
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload) }

            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    let effect = T.Effect(
                        id: 1,
                        operation: { @MainActor env, input in
                            env.value = 1
                            try await Task.sleep(nanoseconds: 1_000_000)
                            let payload = T.Payload()
                            try input.send(.payload(payload))
                        })
                    return effect

                case .payload(let payload):
                    payload.value = 1
                    state = .finished
                    return nil
                }
            }
        }

        let env = T.Env()
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: env)
    }

    // MARK: - Event Effect

    @MainActor
    @Test func createEventEffect() async throws {

        enum T: EffectTransducer {
            class Env { var value: Int = 0 }
            class Payload { var value: Int = 0 }
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload) }
            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    return .event(.payload(T.Payload()))

                case .payload(let payload):
                    payload.value = 1
                    state = .finished
                    return nil
                }
            }
        }

        let env = T.Env()
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: env)
    }

    // MARK: - Operation After Effect

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @MainActor
    @Test
    func createEffectWithIsolatedOperationAfter() async throws {

        enum T: EffectTransducer {
            class Env { var value = 0 }
            class Payload { var value: Int = 0 }
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload) }

            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    let effect = T.Effect(
                        id: "action",
                        isolatedOperation: { env, input, isolated in
                            isolated.preconditionIsolated()
                            env.value = 1
                            let payload = T.Payload()
                            try input.send(.payload(payload))
                        },
                        after: .milliseconds(1)
                    )
                    return effect

                case .payload(let payload):
                    payload.value = 1
                    state = .finished
                    return nil
                }
            }
        }

        let env = T.Env()
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: env)
    }

    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @MainActor
    @Test
    func createEffectWithOperationAfterWithMainActorIsolatedEnv() async throws {

        enum T: EffectTransducer {
            @MainActor class Env { var value = 0 }
            class Payload { var value: Int = 0 }
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload) }

            static func update(_ state: inout State, event: Event) -> T.Effect? {
                switch event {
                case .start:
                    let effect = T.Effect(
                        id: "action",
                        operation: { @MainActor env, input in
                            env.value = 1
                            let payload = T.Payload()
                            try input.send(.payload(payload))
                        },
                        after: .milliseconds(1)
                    )
                    return effect

                case .payload(let payload):
                    payload.value = 1
                    state = .finished
                    return nil
                }
            }
        }

        let env = T.Env()
        let proxy = T.Proxy()
        try proxy.input.send(.start)
        try await T.run(initialState: .start, proxy: proxy, env: env)
    }

    // MARK: - Multiple Effects
    @MainActor
    @Test
    func createMultipleEffects() async throws {
        enum T: EffectTransducer {
            class Env { var value = 0 }
            class Payload {
                init(_ value: Int = 0) { self.value = value }
                var value: Int
            }
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start, payload(Payload), stop }

            typealias Output = Int?

            static func update(_ state: inout State, event: Event) -> (T.Effect?, Output) {
                switch event {
                case .start:
                    return (
                        .combine(
                            makeEffect("1"),
                            makeEffect("2"),
                            makeEffect("3")
                        ), nil
                    )

                case .payload(let payload):
                    return (nil, payload.value)

                case .stop:
                    state = .finished
                    return (nil, -1)
                }
            }

            static func makeEffect(_ id: String) -> T.Effect {
                T.Effect(
                    id: id,
                    isolatedOperation: { env, input, isolated in
                        isolated.assertIsolated()
                        env.value += 1
                        let payload = T.Payload(env.value)
                        try input.send(.payload(payload))
                    })
            }
        }

        var outputs: [Int] = []
        let env = T.Env()
        let proxy = T.Proxy()
        try proxy.send(.start)
        let input = proxy.input
        let result = try await T.run(
            initialState: .start,
            proxy: proxy,
            env: env,
            output: Callback { @MainActor valueOpt in
                if let value = valueOpt {
                    outputs.append(value)
                    if value == 3 {
                        try input.send(.stop)
                    }
                }
            }
        )
        #expect(result == -1)
        #expect(outputs == [1, 2, 3, -1])
    }

}
