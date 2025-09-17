import Oak
import Testing

struct TransducerTests {
    
    @Suite
    struct BasicInitializationTests {
        // MARK: - Test Types

        enum VoidTransducer: Transducer {
            enum State: NonTerminal { case start }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) {}
        }

        enum OutputTransducer: Transducer {
            enum State: NonTerminal { case start }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) -> Int { 1 }
        }

        enum EffectTransducer: Oak.EffectTransducer {
            enum State: NonTerminal { case start }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) -> Self.Effect? { nil }
        }

        enum EffectOutputTransducer: Oak.EffectTransducer {
            enum State: NonTerminal { case start }
            enum Event { case start }
            typealias Output = Int
            static func update(_ state: inout State, event: Event) -> (Self.Effect?, Output) {
                (nil, 1)
            }
        }

        @MainActor
        @Test func createVoidTransducer() async throws {
            typealias T = VoidTransducer
            let proxy = T.Proxy()
            let task1 = Task {
                try await T.run(initialState: .start)
            }
            let task2 = Task {
                try await T.run(initialState: .start, proxy: proxy, env: Void(), output: Callback { _ in })
            }
            task1.cancel()
            task2.cancel()
            #expect(T.Output.self == Void.self)
            #expect(T.Proxy.self == Oak.Proxy<T.Event>.self)
            #expect(T.Env.self == Void.self)
            #expect(T.Effect.self == Never.self)
        }

        @MainActor
        @Test func createOutputTransducer() async throws {
            typealias T = OutputTransducer
            let proxy = T.Proxy()
            let task1 = Task {
                try await T.run(initialState: .start)
            }
            let task2 = Task {
                try await T.run(initialState: .start, proxy: proxy, env: Void(), output: Callback { _ in })
            }
            task1.cancel()
            task2.cancel()
            #expect(T.Output.self == Int.self)
            #expect(T.Proxy.self == Oak.Proxy<T.Event>.self)
            #expect(T.Env.self == Void.self)
            #expect(T.Effect.self == Never.self)
        }

        @MainActor
        @Test func createEffectTransducer() async throws {
            typealias T = EffectTransducer
            let proxy = T.Proxy()
            let task1 = Task {
                try await T.run(initialState: .start, env: T.Env())
            }
            let task2 = Task {
                try await T.run(initialState: .start, proxy: proxy, env: T.Env(), output: Callback { _ in })
            }
            task1.cancel()
            task2.cancel()
            #expect(T.Output.self == Void.self)
            #expect(T.Proxy.self == Oak.Proxy<T.Event>.self)
            #expect(T.Env.self == Void.self)
            #expect(T.Effect.self == Oak.Effect<T>.self)
        }

        @MainActor
        @Test func createEffectOutputTransducer() async throws {
            typealias T = EffectOutputTransducer
            let proxy = T.Proxy()
            let task1 = Task {
                try await T.run(initialState: .start, env: T.Env())
            }
            let task2 = Task {
                try await T.run(initialState: .start, proxy: proxy, env: T.Env(), output: Callback { _ in })
            }
            task1.cancel()
            task2.cancel()
            #expect(T.Output.self == Int.self)
            #expect(T.Proxy.self == Oak.Proxy<T.Event>.self)
            #expect(T.Env.self == Void.self)
            #expect(T.Effect.self == Oak.Effect<T>.self)
        }
    }

    @Suite
    struct TerminalCompletionTests {
        // MARK: - Test Types

        enum VoidTransducer: Transducer {
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) {
                state = .finished
            }
        }

        enum OutputTransducer: Transducer {
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) -> Int {
                state = .finished
                return 1
            }
        }

        enum EffectTransducer: Oak.EffectTransducer {
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start }
            static func update(_ state: inout State, event: Event) -> Self.Effect? {
                state = .finished
                return nil
            }
        }

        enum EffectOutputTransducer: Oak.EffectTransducer {
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool { self == .finished }
            }
            enum Event { case start }
            typealias Output = Int
            static func update(_ state: inout State, event: Event) -> (Self.Effect?, Output) {
                state = .finished
                return (nil, 1)
            }
        }

        @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Expectation
        @MainActor
        @Test func testRunReturnsWithVoidTransducer() async throws {
            typealias T = VoidTransducer
            let expectCompletionCalled = Expectation()
            let expectCallbackCalled = Expectation()
            let proxy = T.Proxy()
            Task {
                try await T.run(initialState: .start, proxy: proxy, output: Callback { _ in
                    expectCallbackCalled.fulfill()
                })
                expectCompletionCalled.fulfill()
            }
            try proxy.send(.start)
            try await expectCallbackCalled.await(nanoseconds: 1_000_000_000)
            try await expectCompletionCalled.await(nanoseconds: 1_000_000_000)
        }

        @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Expectation
        @MainActor
        @Test func testRunReturnsWithOutputTransducer() async throws {
            typealias T = OutputTransducer
            let expectCompletionCalled = Expectation()
            let expectCallbackCalled = Expectation()
            let proxy = T.Proxy()
            Task {
                try await T.run(initialState: .start, proxy: proxy, output: Callback { _ in
                    expectCallbackCalled.fulfill()
                })
                expectCompletionCalled.fulfill()
            }
            try proxy.send(.start)
            try await expectCallbackCalled.await(nanoseconds: 1_000_000_000)
            try await expectCompletionCalled.await(nanoseconds: 1_000_000_000)
        }

        @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Expectation
        @MainActor
        @Test func testRunReturnsWithEffectTransducer() async throws {
            typealias T = EffectTransducer
            let expectCompletionCalled = Expectation()
            // let expectCallbackCalled = Expectation()
            let proxy = T.Proxy()
            Task {
                try await T.run(initialState: .start, proxy: proxy, env: T.Env(), output: Callback { _ in
                    // Note: our current implementation does not call a callback
                    // handler when the output type equals Void.
                    // TODO: This subtle behaviour is currently not sufficently documented.
                    // The better solution should only choose the version which
                    // handles output, when an output parameter is given. Other-
                    // wise it might choose a faster implementation. However,
                    // the compiler *might* optimise this anyway sufficiently.
                    // expectCallbackCalled.fulfill()
                })
                expectCompletionCalled.fulfill()
            }
            try proxy.send(.start)
            // try await expectCallbackCalled.await(nanoseconds: 1000_000_000_000)
            try await expectCompletionCalled.await(nanoseconds: 1000_000_000_000)
        }

        @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) // Expectation
        @MainActor
        @Test func testRunReturnsWithEffectOutputTransducer() async throws {
            typealias T = EffectOutputTransducer
            let expectCompletionCalled = Expectation()
            let expectCallbackCalled = Expectation()
            let proxy = T.Proxy()
            Task {
                try await T.run(initialState: .start, proxy: proxy, env: T.Env(), output: Callback { _ in
                    expectCallbackCalled.fulfill()
                })
                expectCompletionCalled.fulfill()
            }
            try proxy.send(.start)
            try await expectCallbackCalled.await(nanoseconds: 1_000_000_000)
            try await expectCompletionCalled.await(nanoseconds: 1_000_000_000)
        }
    }

    @MainActor
    @Test
    func ensureActionEffectsEventsWillBeExecutedBeforeInputEvents() async throws {
        enum T: EffectTransducer {
            struct Env {}

            enum State: Terminable {
                case start
                case processing(Int)
                case finished

                var isTerminal: Bool {
                    switch self {
                    case .finished: return true
                    default: return false
                    }
                }
            }

            enum Event { case start, actionEvent, operationEvent }

            static func update(_ state: inout State, event: Event) -> Self.Effect? {
                switch event {
                case .start:
                    state = .processing(0)
                    return .combine(
                        .event(.actionEvent),
                        Effect.init(id: "op") { env, input in
                            try input.send(.operationEvent)
                        })

                case .actionEvent:
                    guard case .processing(let count) = state else { fatalError() }
                    let next = count + 1
                    state = .processing(next)
                    if next < 1_000 {
                        return .event(.actionEvent)
                    } else {
                        return nil
                    }

                case .operationEvent:
                    guard case .processing(let count) = state else { fatalError() }
                    #expect(count == 1_000)
                    state = .finished
                    return nil
                }
            }
        }

        let proxy = T.Proxy()
        try proxy.send(.start)
        try await T.run(
            initialState: .start,
            proxy: proxy,
            env: T.Env()
        )
        // #expect(finalState == .finished)
    }

    @TestGlobalActor
    @Test
    func example() async throws {

        enum T: Transducer {
            class Output {
                init(_ value: Int) {
                    self.value = value
                }
                var value: Int
            }
            enum State: Terminable {
                case start, idle(Output), finished
                var isTerminal: Bool {
                    switch self {
                    case .finished: true
                    default: false
                    }
                }
            }
            enum Event { case start, output(Int) }

            static func update(_ state: inout State, event: Event) -> Output {
                switch (event, state) {
                case (.start, .start):
                    let output = Output(0)
                    state = .idle(output)
                    return output

                case (.output(let value), .idle(let output)) where value < 0:
                    state = .finished
                    return output

                case (.output(let value), .idle):
                    let output = Output(value)
                    state = .idle(output)
                    return output

                case (.output(_), .start):
                    fatalError("invalid transition")

                case (.start, .idle(let output)):
                    return output

                case (_, .finished):
                    // can never happen
                    fatalError()
                }
            }

        }

        let proxy = T.Proxy()
        try proxy.send(.start)
        try proxy.send(.output(5))
        try proxy.send(.output(-1))
        let result = try await T.run(
            initialState: .start,
            proxy: proxy,
            output: Callback { @TestGlobalActor output in
                TestGlobalActor.shared.preconditionIsolated()
            }
        )
        #expect(result.value == 5)
    }

    // MARK: - Error Handling Tests
    @Suite
    struct ErrorHandlingTests {
        
        @MainActor
        @Test
        func testInitialStateIsTerminalError() async throws {
            enum T: Transducer {
                enum State: Terminable {
                    case finished
                    var isTerminal: Bool { true }
                }
                enum Event { case start }
                static func update(_ state: inout State, event: Event) -> Int { 0 }
            }

            let proxy = T.Proxy()

            // When initial state is terminal and no initial output provided,
            // it should throw noOutputProduced
            let error = await #expect(throws: TransducerError.self) {
                try await T.run(initialState: .finished, proxy: proxy)
            }
            #expect(error == TransducerError.noOutputProduced)
        }

        @MainActor
        @Test
        func testNoOutputProducedError() async throws {
            enum T: Transducer {
                enum State: Terminable {
                    case start, finished
                    var isTerminal: Bool {
                        if case .finished = self { return true }
                        return false
                    }
                }
                enum Event { case finish }
                typealias Output = Int

                static func update(_ state: inout State, event: Event) -> Int {
                    // Return 0 as the output when finishing
                    state = .finished
                    return 0
                }

            }

            let proxy = T.Proxy()
            try proxy.send(.finish)

            // This should not throw noOutputProduced because update was called
            let result = try await T.run(initialState: .start, proxy: proxy, output: Callback { _ in })
            #expect(result == 0)
        }

        @MainActor
        @Test
        func testProxyAlreadyInUseError() async throws {
            enum T: Transducer {
                enum State: Terminable {
                    case start, running, finished
                    var isTerminal: Bool {
                        if case .finished = self { return true }
                        return false
                    }
                }
                enum Event { case start, finish }
                static func update(_ state: inout State, event: Event) {
                    switch (state, event) {
                    case (.start, .start):
                        state = .running
                    case (.running, .finish):
                        state = .finished
                    default:
                        break
                    }
                }
            }

            let proxy = T.Proxy()
            try proxy.send(.start)  // This will transition to running state but not finish

            // Start first transducer - it will be in running state, not finished
            let task1 = Task {
                try await T.run(initialState: .start, proxy: proxy)
            }

            // Wait a bit to ensure first transducer starts and processes the .start event
            try await Task.sleep(nanoseconds: 10_000_000)  // 10ms

            // Try to start second transducer with same proxy - should throw error
            let error = await #expect(throws: TransducerError.self) {
                try await T.run(initialState: .start, proxy: proxy)
            }
            #expect(error == TransducerError.proxyAlreadyInUse)

            // Now finish the first transducer
            try proxy.send(.finish)
            _ = try await task1.value
        }

        @MainActor
        @Test
        func testEffectTransducerProxyAlreadyInUseError() async throws {
            // EffectTransducer now throws TransducerError.proxyAlreadyInUse instead of fatalError
            enum T: EffectTransducer {
                enum State: Terminable {
                    case start, running, finished
                    var isTerminal: Bool {
                        if case .finished = self { return true }
                        return false
                    }
                }
                enum Event { case start, finish }
                struct Env {}

                static func update(_ state: inout State, event: Event) -> Self.Effect? {
                    switch (state, event) {
                    case (.start, .start):
                        state = .running
                        return nil
                    case (.running, .finish):
                        state = .finished
                        return nil
                    default:
                        return nil
                    }
                }
            }

            let proxy = T.Proxy()
            try proxy.send(.start)  // This will transition to running state but not finish

            // Start first transducer - it will be in running state, not finished
            let task1 = Task {
                try await T.run(initialState: .start, proxy: proxy, env: T.Env())
            }

            // Wait a bit to ensure first transducer starts and processes the .start event
            try await Task.sleep(nanoseconds: 10_000_000)  // 10ms

            // Try to start second transducer with same proxy - should throw error
            let error = await #expect(throws: TransducerError.self) {
                try await T.run(initialState: .start, proxy: proxy, env: T.Env())
            }
            #expect(error == TransducerError.proxyAlreadyInUse)

            // Now finish the first transducer
            try proxy.send(.finish)
            _ = try await task1.value
        }

    }

    // MARK: - Buffer Overflow Tests

    @MainActor
    @Test
    func testEventBufferOverflow() async throws {
        enum T: Transducer {
            enum State: Terminable {
                case idle
                var isTerminal: Bool { false }
            }
            enum Event { case event }
            static func update(_ state: inout State, event: Event) {
                // Never terminates, just accumulates events
            }
        }

        let proxy = T.Proxy(bufferSize: 2)  // Very small buffer

        // Fill buffer beyond capacity
        try proxy.send(.event)
        try proxy.send(.event)

        // This should cause buffer overflow with specific error type
        let error = #expect(throws: Error.self) {
            for _ in 0 ..< 10 {
                try proxy.send(.event)
            }
        }

        // Should be Proxy.Error.droppedEvent
        let description = String(describing: error)
        #expect(description.contains("dropped event") || description.contains("buffer is full"))
    }

    // MARK: - Initial Output Tests (Moore Automaton)

    @MainActor
    @Test
    func testMooreAutomatonWithInitialOutput() async throws {
        enum T: Transducer {
            enum State: Terminable {
                case counting(Int), finished
                var isTerminal: Bool {
                    if case .finished = self { return true }
                    return false
                }
            }
            enum Event { case increment, finish }

            static func update(_ state: inout State, event: Event) -> Int {
                switch (event, state) {
                case (.increment, .counting(let count)):
                    let newCount = count + 1
                    state = .counting(newCount)
                    return newCount
                case (.finish, .counting(let count)):
                    state = .finished
                    return count
                case (.increment, .finished), (.finish, .finished):
                    return 0
                }
            }

            static func initialOutput(initialState: State) -> Int? {
                if case .counting(let count) = initialState {
                    return count  // Return initial count for Moore automaton
                }
                return nil
            }
        }

        let proxy = T.Proxy()
        try proxy.send(.increment)
        try proxy.send(.increment)
        try proxy.send(.finish)

        let result = try await T.run(
            initialState: .counting(0),
            proxy: proxy,
            output: Callback { _ in }
        )
        #expect(result == 2)
    }

    // MARK: - Multiple Event Processing Tests

    @MainActor
    @Test
    func testMultipleEventsInSequence() async throws {
        enum T: Transducer {
            enum State: Terminable {
                case counting(Int), finished
                var isTerminal: Bool {
                    if case .finished = self { return true }
                    return false
                }
            }
            enum Event { case increment, decrement, finish }

            static func update(_ state: inout State, event: Event) -> Int {
                switch (event, state) {
                case (.increment, .counting(let count)):
                    let newCount = count + 1
                    state = .counting(newCount)
                    return newCount
                case (.decrement, .counting(let count)):
                    let newCount = count - 1
                    state = .counting(newCount)
                    return newCount
                case (.finish, .counting(let count)):
                    state = .finished
                    return count
                case (_, .finished):
                    return 0
                }
            }

            static func initialOutput(initialState: State) -> Int? {
                if case .counting(let count) = initialState {
                    return count  // Return initial count for Moore automaton
                }
                return nil
            }
        }

        let proxy = T.Proxy()

        try proxy.send(.increment)  // 1
        try proxy.send(.increment)  // 2
        try proxy.send(.decrement)  // 1
        try proxy.send(.increment)  // 2
        try proxy.send(.finish)

        let result = try await T.run(
            initialState: .counting(0),
            proxy: proxy,
            output: Callback { output in
                // Just verify we receive outputs
            }
        )

        #expect(result == 2)
    }

    // MARK: - Invalid State Transition Tests

    @MainActor
    @Test
    func testValidStateTransitions() async throws {
        enum T: Transducer {

            enum State: Terminable {
                case start, processing, finished
                var isTerminal: Bool {
                    if case .finished = self { return true }
                    return false
                }
            }
            enum Event { case start, process }

            static func update(_ state: inout State, event: Event) -> String {
                switch (event, state) {
                case (.start, .start):
                    state = .processing
                    return "started"
                case (.process, .processing):
                    state = .finished
                    return "finished"
                default:
                    return "ignored"
                }
            }

        }

        let proxy = T.Proxy()
        try proxy.send(.start)
        try proxy.send(.process)

        let result = try await T.run(
            initialState: .start,
            proxy: proxy,
            output: Callback { _ in }
        )
        #expect(result == "finished")
    }

    // MARK: - Output Subject Tests

    @MainActor
    @Test
    func testOutputSubjectReceivesAllValues() async throws {
        enum T: Transducer {
            enum State: Terminable {
                case counting(Int), finished
                var isTerminal: Bool {
                    if case .finished = self { return true }
                    return false
                }
            }
            enum Event { case increment, finish }

            static func update(_ state: inout State, event: Event) -> String {
                switch (event, state) {
                case (.increment, .counting(let count)):
                    let newCount = count + 1
                    state = .counting(newCount)
                    return "Count: \(newCount)"
                case (.finish, .counting(let count)):
                    state = .finished
                    return "Final: \(count)"
                case (_, .finished):
                    return "Done"
                }
            }

        }

        let proxy = T.Proxy()

        try proxy.send(.increment)
        try proxy.send(.increment)
        try proxy.send(.increment)
        try proxy.send(.finish)

        let result = try await T.run(
            initialState: .counting(0),
            proxy: proxy,
            output: Callback { output in
                // Output received successfully
            }
        )

        #expect(result == "Final: 3")
    }

    // MARK: - Effect Combination Tests

    @MainActor
    @Test
    func testEffectCombination() async throws {
        enum T: EffectTransducer {
            enum State: Terminable {
                case start, processing, finished
                var isTerminal: Bool {
                    if case .finished = self { return true }
                    return false
                }
            }
            enum Event { case start, effect1Done, effect2Done }
            struct Env { var value: Int = 0 }

            static func update(_ state: inout State, event: Event) -> Self.Effect? {
                switch event {
                case .start:
                    state = .processing
                    return .combine(
                        .event(.effect1Done),
                        .event(.effect2Done)
                    )
                case .effect1Done:
                    return nil
                case .effect2Done:
                    state = .finished
                    return nil
                }
            }
        }

        let proxy = T.Proxy()
        try proxy.send(.start)

        try await T.run(
            initialState: .start,
            proxy: proxy,
            env: T.Env()
        )
        // Should complete without error
    }

    // MARK: - Void Output Tests

    @MainActor
    @Test
    func testVoidOutputTransducer() async throws {
        enum T: Transducer {
            enum State: Terminable {
                case start, finished
                var isTerminal: Bool {
                    if case .finished = self { return true }
                    return false
                }
            }
            enum Event { case finish }

            static func update(_ state: inout State, event: Event) {
                switch event {
                case .finish:
                    state = .finished
                }
            }
        }

        let proxy = T.Proxy()
        try proxy.send(.finish)

        try await T.run(initialState: .start, proxy: proxy)
        // Should complete successfully with Void output
    }

}
