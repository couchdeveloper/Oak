#if false
import Testing
import Oak
@testable import struct Oak.TransducerDidNotProduceAnOutputError
@testable import struct Oak.ProxyTerminationError
@testable import struct Oak.ProxyInvalidatedError

private final class Host<State> {
    var state: State

    init(initialState: State) {
        self.state = initialState
    }
}

@Suite("TransducerTests")
struct TransducerTests {

    @Suite("Type Inference Tests")
    struct TypeInferenceTests {

        @MainActor
        @Test func testTypeInference1() async throws {
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    case terminated
                    var isTerminal: Bool {
                        if case .terminated = self { true } else { false }
                    }
                }
                enum Event { case start }
                static func update(_ state: inout State, event: Event) {}
            }

            #expect(T.Output.self == Never.self)
            #expect(T.Env.self == Never.self)
            #expect(T.TransducerOutput.self == Void.self)
            #expect(T.Proxy.self == Proxy<T.Event>.self)
        }

        @MainActor
        @Test func testTypeInference2() async throws {
            enum T: Transducer {
                enum State: Terminable { case start }
                enum Event { case start }
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> Int { 0 }
            }

            #expect(T.Output.self == Int.self)
            #expect(T.Env.self == Never.self)
            #expect(T.TransducerOutput.self == Int.self)
            #expect(T.Proxy.self == Proxy<T.Event>.self)
        }

        @MainActor
        @Test func testTypeInference3() async throws {
            enum T: Transducer {
                enum State: Terminable { case start }
                enum Event { case start }
                typealias Output = (Int, Int)
                static func update(_ state: inout State, event: Event) -> (Int, Int) { (0, 0) }
            }

            #expect(T.Output.self == (Int, Int).self)
            #expect(T.Env.self == Never.self)
            #expect(T.TransducerOutput.self == (Int, Int).self)
            #expect(T.Proxy.self == Proxy<T.Event>.self)
        }

        @MainActor
        @Test func testTypeInference4() async throws {
            enum T: Transducer {
                enum State: Terminable { case start }
                enum Event { case start }
                struct Env {}
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> (Effect<Self>?, Int) {
                    (.none, 0)
                }
            }

            #expect(T.Output.self == Int.self)
            #expect(T.TransducerOutput.self == (Effect<T>?, Int).self)
            #expect(T.Proxy.self == Proxy<T.Event>.self)
        }

        @MainActor
        @Test func testTypeInference5() async throws {
            enum T: Transducer {
                enum State: Terminable { case start }
                enum Event { case start }
                struct Env {}
                typealias Output = (Int, Int)
                static func update(
                    _ state: inout State, event: Event
                ) -> (
                    Effect<Self>?, (Int, Int)
                ) { (.none, (0, 0)) }
            }

            #expect(T.Output.self == (Int, Int).self)
            #expect(T.TransducerOutput.self == (Effect<T>?, (Int, Int)).self)
            #expect(T.Proxy.self == Proxy<T.Event>.self)
        }

        @MainActor
        @Test func testTypeInference6() async throws {
            enum T: Transducer {
                enum State: Terminable { case start }
                enum Event { case start }
                struct Env {}
                static func update(_ state: inout State, event: Event) -> Effect<Self>? {
                    .none
                }
            }

            #expect(T.Output.self == Never.self)
            #expect(T.TransducerOutput.self == Effect<T>?.self)
            #expect(T.Proxy.self == Proxy<T.Event>.self)
        }

    }
}

extension TransducerTests {

    @Suite("run tests")
    struct RunTests {

        @MainActor
        @Test func testRunWithInternalState1() async throws {
            // (inout State, Event) -> Void
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    case finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start }
                typealias Output = Void
                static func update(_ state: inout State, event: Event) {
                    switch event {
                    case .start: state = .finished
                    }
                }
            }
            let proxy = T.Proxy(initialEvents: .start)
            let result: Void = try await T.run(
                initialState: .start,
                proxy: proxy
            )
            #expect(result == ())
            #expect(proxy.isTerminated)
        }

        @MainActor
        @Test func testRunWithInternalState2() async throws {
            // (inout State, Event) -> Void
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    case finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start }
                typealias Output = Void
                static func update(_ state: inout State, event: Event) {
                    switch event {
                    case .start: state = .finished
                    }
                }
            }
            let proxy = T.Proxy(initialEvents: .start)
            let result: Void = try await T.run(
                initialState: .start,
                proxy: proxy
            )
            #expect(result == ())
            #expect(proxy.isTerminated)
        }

        @MainActor
        @Test func testRunWithHost1() async throws {
            // (inout State, Event) -> Void
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    case finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start }
                typealias Output = Void
                static func update(_ state: inout State, event: Event) {
                    switch event {
                    case .start: state = .finished
                    }
                }
            }

            let host = Host<T.State>(initialState: .start)

            let proxy = T.Proxy(initialEvents: .start)
            try await T.run(
                state: \.state,
                host: host,
                proxy: proxy,
                out: NoCallbacks(),
                initialOutput: Void()
            )
            #expect(host.state == .finished)
            #expect(proxy.isTerminated)
        }

        @MainActor
        @Test func testRunWithHost2() async throws {
            // (inout State, Event) -> Void
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    case finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start }
                typealias Output = Void
                static func update(_ state: inout State, event: Event) {
                    switch event {
                    case .start: state = .finished
                    }
                }
            }

            let host = Host<T.State>(initialState: .start)

            let proxy = T.Proxy(initialEvents: .start)
            try await T.run(
                state: \.state,
                host: host,
                proxy: proxy,
            )
            #expect(host.state == .finished)
            #expect(proxy.isTerminated)
        }

        @MainActor
        @Test func testRunWithInternalStateWithOutput1() async throws {
            // (inout State, Event) -> Int
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    case finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start }
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> Int {
                    switch event {
                    case .start:
                        state = .finished
                        return 2
                    }
                }
            }
            let proxy = T.Proxy(initialEvents: .start)
            let result = try await T.run(
                initialState: .start,
                proxy: proxy,
                out: NoCallbacks(),
                initialOutput: 1
            )
            #expect(result == 2)
            #expect(proxy.isTerminated)
        }

        @MainActor
        @Test func testRunWithInternalStateWithOutput2() async throws {
            // (inout State, Event) -> (Int, Int)
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    case finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start }
                typealias Output = (Int, Int)
                static func update(_ state: inout State, event: Event) -> (Int, Int) {
                    switch event {
                    case .start:
                        state = .finished
                        return (2, 2)
                    }
                }
            }
            let proxy = T.Proxy(initialEvents: .start)
            let result = try await T.run(
                initialState: .start,
                proxy: proxy,
                out: NoCallbacks(),
                initialOutput: (1, 1)
            )
            #expect(result == (2, 2))
            #expect(proxy.isTerminated)
        }

        @MainActor
        @Test func testRunWithInternalStateWithEffectAndOutput1() async throws {
            // (inout State, Event) -> (Effect?, Int)
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    case finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start, finish }
                struct Env {}
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> (Effect<Self>?, Int) {
                    switch (event, state) {
                    case (.start, .start):
                        return (.event(.finish), 1)
                    case (.finish, .start):
                        state = .finished
                        return (.none, 2)
                    case (_, .finished):
                        return (.none, -1)
                    }
                }
            }

            let proxy = T.Proxy(initialEvents: .start)
            let result = try await T.run(
                initialState: .start,
                proxy: proxy,
                env: T.Env(),
                out: NoCallbacks(),
                initialOutput: 0
            )
            #expect(result == 2)
            #expect(proxy.isTerminated)
        }

        @MainActor
        @Test func testRunWithInternalStateWithEffectAndOutput2() async throws {
            // (inout State, Event) -> (Effect?, (Int,Int))
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    case finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start, finish }
                struct Env {}
                typealias Output = (Int, Int)
                static func update(
                    _ state: inout State, event: Event
                ) -> (
                    Effect<Self>?, (Int, Int)
                ) {
                    switch (event, state) {
                    case (.start, .start):
                        return (Effect<Self>.event(.finish), (1, 1))
                    case (.finish, .start):
                        state = .finished
                        return (.none, (2, 2))
                    case (_, .finished):
                        return (.none, (-1, -1))
                    }
                }
            }
            let proxy = T.Proxy(initialEvents: .start)
            let result = try await T.run(
                initialState: .start,
                proxy: proxy,
                env: T.Env(),
                out: NoCallbacks(),
                initialOutput: (0, 0)
            )
            #expect(result == (2, 2))
            #expect(proxy.isTerminated)
        }

        @MainActor
        @Test func testRunWithInternalStateWithEffect1() async throws {
            // (inout State, Event) -> Effect?
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    case finished
                    var isTerminal: Bool { self == .finished }
                }
                enum Event { case start, finish }
                struct Env {}
                static func update(_ state: inout State, event: Event) -> Effect<Self>? {
                    switch (event, state) {
                    case (.start, .start):
                        return .event(.finish)
                    case (.finish, .start):
                        state = .finished
                        return .none
                    case (_, .finished):
                        return .none
                    }
                }
            }
            let proxy = T.Proxy(initialEvents: .start)
            try await T.run(
                initialState: .start,
                proxy: proxy,
                env: T.Env()
            )
            #expect(proxy.isTerminated)
        }

    }

    @Suite("run failure tests")
    struct RunThrowingErrorTests {
        @MainActor
        @Test func testRunThrowsWhenTerminatedWithoutResult1() async throws {
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    var isTerminal: Bool { true }
                }
                enum Event { case start }
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> Int { 0 }
            }
            await #expect(
                throws: TransducerDidNotProduceAnOutputError.self,
                performing: {
                    try await T.run(
                        initialState: .start,
                        proxy: T.Proxy(),
                        out: NoCallbacks(),
                        initialOutput: nil
                    )
                }
            )
        }

        @MainActor
        @Test func testRunThrowsWhenTerminatedWithoutResult2() async throws {
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    var isTerminal: Bool { true }
                }
                enum Event { case start }
                struct Env {}
                typealias Output = (Int, Int)
                static func update(
                    _ state: inout State, event: Event
                ) -> (
                    Effect<Self>?, (Int, Int)
                ) { (.none, (0, 0)) }
            }
            await #expect(
                throws: TransducerDidNotProduceAnOutputError.self,
                performing: {
                    try await T.run(
                        initialState: .start,
                        proxy: T.Proxy(),
                        env: T.Env(),
                        out: NoCallbacks(),
                        initialOutput: nil
                    )
                }
            )
        }

    }
}

extension TransducerTests {

    @Suite("proxy termination tests")
    struct ProxyTerminationTests {
        @MainActor
        @Test func throwsErrorWhenTerminatedByProxy1() async throws {
            enum T: Transducer {
                enum State: Terminable { case start }
                enum Event { case start }
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> Int { 0 }
            }

            let proxy = T.Proxy()
            Task {
                await #expect(
                    throws: ProxyTerminationError.self,
                    performing: {
                        try await T.run(
                            initialState: .start,
                            proxy: proxy,
                            out: NoCallbacks(),
                            initialOutput: nil
                        )
                    }
                )
            }
            proxy.terminate()
        }

        @MainActor
        @Test func throwsErrorWhenTerminatedByProxy2() async throws {
            enum T: Transducer {
                enum State: Terminable { case start }
                enum Event { case start }
                struct Env {}
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> (Effect<Self>?, Int) {
                    (.none, 0)
                }
            }

            let proxy = T.Proxy()
            Task {
                await #expect(
                    throws: ProxyTerminationError.self,
                    performing: {
                        try await T.run(
                            initialState: .start,
                            proxy: proxy,
                            env: T.Env(),
                            out: NoCallbacks(),
                            initialOutput: nil
                        )
                    }
                )
            }
            proxy.terminate()
        }

        @MainActor
        @Test func cancelsTasksAndThrowsErrorWhenTerminatedByProxy() async throws {

            enum T: Transducer {
                enum State: Terminable { case start }
                enum Event { case start }
                struct Env {
                    let confirmation: Confirmation
                }
                typealias Effect = Oak.Effect<Self>
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> (Effect?, Int) {
                    switch (event, state) {
                    case (.start, .start):
                        return (effect(), 0)
                    }
                }

                static func effect() -> Effect {
                    Effect(id: 1) { env, _ in
                        env.confirmation()
                        await #expect(
                            throws: CancellationError.self,
                            performing: {
                                try await Task.sleep(nanoseconds: 1_000_000_000)
                            }
                        )
                    }
                }
            }

            let proxy = T.Proxy()
            Task {
                try proxy.send(.start)
                try? await Task.sleep(nanoseconds: 10_000_000)
                proxy.terminate()
            }
            let _ = await confirmation("effect", expectedCount: 1) { confirm in
                await #expect(
                    throws: ProxyTerminationError.self,
                    performing: {
                        try await T.run(
                            initialState: .start,
                            proxy: proxy,
                            env: T.Env(confirmation: confirm),
                            out: NoCallbacks(),
                            initialOutput: nil
                        )
                    }
                )
            }
        }

        @MainActor
        @Test func proxySendThrowsErrorWhenEffectIsCancelled() async throws {
            // Test if `proxy.send(event)` called in the effect's operation
            // will throw when the Swift Task has been cancelled.

            // This transducer will start a timer sending "pings" continuosly
            // to the transducer. Once it is started, it immediately starts
            // another timer which the same id causing the first to cancel.
            // Since the first timer attempts to send events even when its Task
            // has been cancelld - which it can do only once – it is expected
            // that the send function will throw an error.
            enum T: Transducer {
                enum State: Terminable {
                    case start, counting, terminated
                    var isTerminal: Bool { if case .terminated = self { true } else { false } }
                }
                enum Event { case start, startTimer, stopTimer, terminate, tick }
                struct Env {}
                typealias Effect = Oak.Effect<Self>
                static func update(_ state: inout State, event: Event) -> Effect? {
                    switch (event, state) {
                    case (.start, .start):
                        state = .counting
                        return singletonTimer(tag: "first")
                    case (.startTimer, .counting):
                        return singletonTimer(tag: "second")
                    case (.stopTimer, .counting):
                        return .cancelTask(1)
                    case (.tick, .counting):
                        return .none
                    case (.terminate, _):
                        state = .terminated
                        return .none

                    case (.tick, .start):
                        return .none
                    case (.startTimer, .start):
                        return .none
                    case (.start, .counting):
                        return .none
                    case (.stopTimer, .start):
                        return .none
                    case (_, .terminated):
                        return .none
                    }
                }

                static func singletonTimer(tag: String) -> Effect {
                    Effect(id: 1) { env, proxy in
                        await #expect(
                            throws: ProxyInvalidatedError.self,
                            performing: {
                                // This is an incorrectly implemented operation,
                                // which does not respect the cancellation state
                                // of the current Task. In this test, the operation
                                // will call `try proxy.send(.tick)` _once_ after
                                // the task has been cancelled and cause the
                                // `send(_:)` function to throw `ProxyInvalidatedError`.
                                while true {
                                    try proxy.send(.tick)  // should throw ProxyInvalidatedError when the Task is cancelled.
                                    try? await Task.sleep(nanoseconds: 1_000_000)
                                }
                            }
                        )
                    }
                }
            }

            struct TestError: Error {}
            let proxy = T.Proxy()
            Task {
                try proxy.send(.start)
                try? await Task.sleep(nanoseconds: 5_000_000)
                try proxy.send(.startTimer)
                try? await Task.sleep(nanoseconds: 5_000_000)
                try proxy.send(.stopTimer)
                try? await Task.sleep(nanoseconds: 5_000_000)
                try? proxy.send(.terminate)
            }

            try await T.run(
                initialState: .start,
                proxy: proxy,
                env: T.Env()
            )
        }
    }
}

extension TransducerTests {

    @Suite("transducer variants tests")
    struct TransducerVariantsTest {

        enum T1: Transducer {

            enum State: Terminable {
                case start, running, finished
                var isTerminal: Bool {
                    if case .finished = self { true } else { false }
                }
            }
            enum Event {
                case start, cancel
            }

            typealias Output = (Int, String)
            static func update(_ state: inout State, event: Event) -> (Int, String) {
                switch (event, state) {
                case (.start, .start):
                    state = .running
                    return (0, "running")
                case (.start, .running):
                    return (1, "running")
                case (.cancel, .running):
                    state = .finished
                    return (2, "finished")
                default:
                    return (-1, "??")
                }
            }
        }

        @MainActor
        @Test func testResultRunWithInternalState() async throws {
            let proxy = T1.Proxy()
            try proxy.send(.start)
            try proxy.send(.cancel)

            let result = try await T1.run(
                initialState: .start,
                proxy: proxy
            )
            #expect(result == (2, "finished"))
        }

        @MainActor
        @Test func testResultRunWithExternalState() async throws {
            let proxy = T1.Proxy()
            try proxy.send(.start)
            try proxy.send(.cancel)

            let host = Host<T1.State>(initialState: .start)
            let result = try await T1.run(
                state: \.state,
                host: host,
                proxy: proxy
            )

            #expect(result == (2, "finished"))
        }

        @MainActor
        @Test func testOutputRunWithInternalState() async throws {
            let proxy = T1.Proxy()
            var out1: [Int] = []
            var out2: [String] = []

            try proxy.send(.start)
            try proxy.send(.cancel)
            _ = try await T1.run(
                initialState: .start,
                proxy: proxy,
                out: Callback { @MainActor in
                    out1.append($0.0)
                    out2.append($0.1)
                }
            )

            #expect(out1 == [0, 2])
            #expect(out2 == ["running", "finished"])
        }

        @MainActor
        @Test func testOutputRunWithExternalState() async throws {
            let host = Host<T1.State>(initialState: .start)
            let proxy = T1.Proxy()
            var out1: [Int] = []
            var out2: [String] = []

            try proxy.send(.start)
            try proxy.send(.cancel)
            _ = try await T1.run(
                state: \.state,
                host: host,
                proxy: proxy,
                out: Callback { @MainActor in
                    out1.append($0.0)
                    out2.append($0.1)
                }
            )

            #expect(out1 == [0, 2])
            #expect(out2 == ["running", "finished"])
        }

    }
}

extension TransducerTests {

    @Suite("result and output tests")
    struct ResultAndOutputTests {

        enum T1: Transducer {
            enum State: Terminable {
                case start, running, finished
                var isTerminal: Bool {
                    if case .finished = self { true } else { false }
                }
            }
            enum Event {
                case start, cancel, ping
            }

            struct Env {}

            typealias Effect = Oak.Effect<Self>

            typealias Output = (Int, String)

            static func update(_ state: inout State, event: Event) -> (Effect?, (Int, String)) {
                switch (event, state) {
                case (.start, .start):
                    state = .running
                    return (.event(.ping), (0, "running"))
                case (.start, .running):
                    return (.none, (1, "running"))
                case (.cancel, .running):
                    state = .finished
                    return (.none, (2, "finished"))
                case (.ping, _):
                    return (.none, (3, "ping"))

                default:
                    return (.none, (-1, "??"))
                }
            }
        }

        @MainActor
        @Test func testResultRunWithInternalState() async throws {
            let proxy = T1.Proxy()
            try proxy.send(.start)
            try proxy.send(.cancel)

            let result = try await T1.run(
                initialState: .start,
                proxy: proxy,
                env: T1.Env()
            )
            #expect(proxy.isTerminated)
            #expect(result == (2, "finished"))
        }

        @MainActor
        @Test func testResultRunWithExternalState() async throws {
            let proxy = T1.Proxy()
            try proxy.send(.start)
            try proxy.send(.cancel)

            let host = Host<T1.State>(initialState: .start)
            let result = try await T1.run(
                state: \.state,
                host: host,
                proxy: proxy,
                env: T1.Env()
            )

            #expect(proxy.isTerminated)
            #expect(result == (2, "finished"))
        }

        @MainActor
        @Test func testOutputRunWithInternalState() async throws {
            let proxy = T1.Proxy()
            var out1: [Int] = []
            var out2: [String] = []

            try proxy.send(.start)
            try proxy.send(.cancel)
            _ = try await T1.run(
                initialState: .start,
                proxy: proxy,
                env: T1.Env(),
                out: Callback { @MainActor output in
                    out1.append(output.0)
                    out2.append(output.1)
                }
            )

            #expect(proxy.isTerminated)
            #expect(out1 == [0, 2])
            #expect(out2 == ["running", "finished"])
        }

        @MainActor
        @Test func testOutputRunWithExternalState() async throws {
            let host = Host<T1.State>(initialState: .start)
            let proxy = T1.Proxy()
            var out1: [Int] = []
            var out2: [String] = []

            try proxy.send(.start)
            try proxy.send(.cancel)
            _ = try await T1.run(
                state: \.state,
                host: host,
                proxy: proxy,
                env: T1.Env(),
                out: Callback { @MainActor output in
                    out1.append(output.0)
                    out2.append(output.1)
                }
            )

            #expect(proxy.isTerminated)
            #expect(out1 == [0, 2])
            #expect(out2 == ["running", "finished"])
        }
    }

}

extension TransducerTests {

    protocol Shutdownable {
        func shutdown() async throws
    }

    @Suite("Event with Playload")
    struct EventWithPayload {

        enum T1<Context: Sendable & Shutdownable & DefaultInitializable>: Transducer {
            enum State: Terminable {
                case start
                case initialising
                case idle(context: Context)
                case shuttingDown(context: Context)
                case finished
                var isTerminal: Bool {
                    if case .finished = self { true } else { false }
                }
            }
            enum Event {
                case start
                case context(Context)
                case shutdown
                case didShutdown
            }
            struct Env {}
            typealias Effect = Oak.Effect<Self>

            static func update(_ state: inout State, event: Event) -> Effect? {
                switch (state, event) {
                case (.start, .start):
                    state = .initialising
                    return makeContext()

                case (.initialising, .context(let context)):
                    state = .idle(context: context)
                    return nil

                case (.idle(let context), .shutdown):
                    state = .shuttingDown(context: context)
                    return shutdownContext(context: context)

                case (.shuttingDown, .didShutdown):
                    state = .finished
                    return nil

                case (.finished, _):
                    return nil

                case (_, _):
                    print("unhandled event \(event) at state \(state)")
                    return nil
                }
            }

            static func makeContext() -> Effect {
                .action { env, proxy in
                    let context = Context()
                    try? proxy.send(.context(context))
                }
            }

            static func shutdownContext(context: Context) -> Effect {
                .task { env, proxy in
                    print("where I'm running on?")
                    try await context.shutdown()
                    try proxy.send(.didShutdown)
                }
            }

        }

        @Test
        func testEventWithPayload() async throws {
            class NonSendableContext: Shutdownable & DefaultInitializable {
                required init() {
                    MainActor.shared.preconditionIsolated()
                }

                func shutdown() async throws {
                    try await Task.sleep(nanoseconds: 1_000_000)
                }
            }

            final class SendableContext: Sendable & Shutdownable & DefaultInitializable {
                init() {
                    MainActor.shared.preconditionIsolated()
                }

                func shutdown() async throws {
                    try await Task.sleep(nanoseconds: 1_000_000)
                }
            }

            typealias Example = T1<SendableContext>
            let proxy = Example.Proxy()
            try proxy.send(.start)

            Task {
                try await Task.sleep(nanoseconds: 1_000_000)
                try proxy.send(.shutdown)
            }

            let task = Task { @MainActor in
                try await Example.run(
                    initialState: .start,
                    proxy: proxy,
                    env: Example.Env()
                )
            }
            try await task.value
        }
    }

    func example() {

    }
}
extension TransducerTests {

    @Suite("Timer Example")
    struct TimerExample {
        @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
        enum T1: Transducer {
            enum State: Terminable {
                case start, running, finished
                var isTerminal: Bool {
                    if case .finished = self { true } else { false }
                }
            }
            enum Event {
                case start, cancel, ping
            }

            struct Env {}

            typealias Effect = Oak.Effect<Self>

            typealias Output = (Int, String)

            static func update(_ state: inout State, event: Event) -> (Effect?, (Int, String)) {
                switch (event, state) {
                case (.start, .start):
                    state = .running
                    return (.event(.ping, id: "ping", after: .milliseconds(10)), (0, "running"))
                case (.start, .running):
                    return (.none, (1, "running"))
                case (.cancel, .running):
                    state = .finished
                    return (.none, (2, "finished"))
                case (.ping, .running):
                    return (.event(.ping, id: "ping", after: .milliseconds(10)), (3, "ping"))

                case (_, .finished):
                    return (.none, (-1, "??"))
                case (.ping, .start):
                    return (.none, (-1, "??"))
                case (.cancel, .start):
                    return (.none, (-1, "??"))
                }
            }
        }

        @MainActor
        @Test
        func testEventEffect() async throws {
            if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
                let proxy = T1.Proxy()
                Task {
                    try proxy.send(.start)
                    try await Task.sleep(for: .seconds(0.05))
                    try proxy.send(.cancel)
                }

                let result = try await T1.run(
                    initialState: .start,
                    proxy: proxy,
                    env: T1.Env(),
                    out: Callback { output in
                        print(output)
                    }
                )
                #expect(result == (2, "finished"))
            } else {

            }
        }
    }
}
#endif
