import Testing
import Oak
@testable import struct Oak.TransducerDidNotProduceAnOutputError
@testable import struct Oak.ProxyTerminationError
@testable import struct Oak.ProxyInvalidatedError

fileprivate final class Store<State> {
    var state: State
    
    init(state: State) {
        self.state = state
    }
}


struct TransducerTests  {
    
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
                typealias Output = Void
                static func update(_ state: inout State, event: Event) -> Void { }
            }
            
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
                static func update(_ state: inout State, event: Event) -> (Effect<Event, Env>?, Int) { (.none, 0) }
            }
            
            #expect(T.TransducerOutput.self == (Effect<T.Event, T.Env>?, Int).self)
            #expect(T.Proxy.self == Proxy<T.Event>.self)
        }
        
        @MainActor
        @Test func testTypeInference5() async throws {
            enum T: Transducer {
                enum State: Terminable { case start }
                enum Event { case start }
                struct Env {}
                typealias Output = (Int, Int)
                static func update(_ state: inout State, event: Event) -> (Effect<Event, Env>?, (Int, Int)) { (.none, (0, 0)) }
            }
            
            #expect(T.TransducerOutput.self == (Effect<T.Event, T.Env>?, (Int, Int)).self)
            #expect(T.Proxy.self == Proxy<T.Event>.self)
        }
    }
}

extension TransducerTests {
    
    struct RunTests {
        
        @MainActor
        @Test func testRun1() async throws {
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    var isTerminal: Bool { true }
                }
                enum Event { case start }
                typealias Output = Void
                static func update(_ state: inout State, event: Event) -> Void { }
            }
            let proxy = T.Proxy()
            let result: Void = try await T.run(initialState: .start, proxy: proxy, out: NoCallbacks(), initialOutput: Void())
            #expect(result == ())
        }
     
        @MainActor
        @Test func testRun2() async throws {
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    var isTerminal: Bool { true }
                }
                enum Event { case start }
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> Int { 0 }
            }
            
            let result = try await T.run(initialState: .start, proxy: T.Proxy(), out: NoCallbacks(), initialOutput: 1)
            #expect(result == 1)
        }

        @MainActor
        @Test func testRun3() async throws {
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    var isTerminal: Bool { true }
                }
                enum Event { case start }
                typealias Output = (Int, Int)
                static func update(_ state: inout State, event: Event) -> (Int, Int) { (0, 0) }
            }
            let result = try await T.run(initialState: .start, proxy: T.Proxy(), out: NoCallbacks(), initialOutput: (1, 1))
            #expect(result == (1, 1))
        }
        
        @MainActor
        @Test func testRun4() async throws {
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    var isTerminal: Bool { true }
                }
                enum Event { case start }
                struct Env {}
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> (Effect<Event, Env>?, Int) { (.none, 0) }
            }
            
            let result = try await T.run(initialState: .start, proxy: T.Proxy(), env: T.Env(), out: NoCallbacks(), initialOutput: 1)
            #expect(result == 1)
        }

        @MainActor
        @Test func testRun5() async throws {
            enum T: Transducer {
                enum State: Terminable {
                    case start
                    var isTerminal: Bool { true }
                }
                enum Event { case start }
                struct Env {}
                typealias Output = (Int, Int)
                static func update(_ state: inout State, event: Event) -> (Effect<Event, Env>?, (Int, Int)) { (.none, (0, 0)) }
            }
            let result = try await T.run(initialState: .start, proxy: T.Proxy(), env: T.Env(), out: NoCallbacks(), initialOutput: (1, 1))
            #expect(result == (1, 1))
        }

    }

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
                performing: { try await T.run(
                    initialState: .start,
                    proxy: T.Proxy(),
                    out: NoCallbacks(),
                    initialOutput: nil
                )}
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
                static func update(_ state: inout State, event: Event) -> (Effect<Event, Env>?, (Int, Int)) { (.none, (0, 0)) }
            }
            await #expect(
                throws: TransducerDidNotProduceAnOutputError.self,
                performing: { try await T.run(
                    initialState: .start,
                    proxy: T.Proxy(),
                    env: T.Env(),
                    out: NoCallbacks(),
                    initialOutput: nil
                )}
            )
        }

    }

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
                static func update(_ state: inout State, event: Event) -> (Effect<Event, Env>?, Int) { (.none, 0) }
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
                typealias Effect = Oak.Effect<Event, Env>
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> (Effect?, Int) {
                    switch (event, state) {
                    case (.start, .start):
                        return (effect, 0)
                    }
                }
                
                static let effect = Effect(id: 1) { env, _ in
                    env.confirmation()
                    await #expect(
                        throws: CancellationError.self,
                        performing: {
                            try await Task.sleep(nanoseconds: 1_000_000_000)
                        }
                    )
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
            
            enum T: Transducer {
                enum State: Terminable { case start, counting }
                enum Event { case start, startTimer, tick }
                struct Env {}
                typealias Effect = Oak.Effect<Event, Env>
                typealias Output = Int
                static func update(_ state: inout State, event: Event) -> (Effect?, Int) {
                    switch (event, state) {
                    case (.start, .start):
                        state = .counting
                        return (singletonTimer(tag: "first"), 0)
                    case (.startTimer, .counting):
                        return (singletonTimer(tag: "second"), 1)
                    case (.tick, .start):
                        return (.none, 2)
                    case (.tick, .counting):
                        return (.none, 2)
                    case (.startTimer, .start):
                        return (.none, -1)
                    case (.start, .counting):
                        return (.none, -2)
                    }
                }
                
                static func singletonTimer(tag: String) -> Effect {
                    Effect(id: 1) { env, proxy in
                        await #expect(
                            throws: ProxyInvalidatedError.self,
                            performing: {
                                // This is an incorrectly implemented operation,
                                // which does not respect the cancellation state
                                // of the current Task:
                                while true {
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                    do {
                                        print("timer: \(tag) sending tick")
                                        try proxy.send(.tick) // should throw ProxyInvalidatedError when the Task is cancelled.
                                    } catch {
                                        print("error: \(tag): \(error)")
                                        throw error
                                    }
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
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                try proxy.send(.startTimer)
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                proxy.terminate(failure: TestError())
            }
            
            try await T.run(
                initialState: .start,
                proxy: proxy,
                env: T.Env(),
                out: NoCallbacks()
            )

            try await Task.sleep(nanoseconds: 1000_000_000_000)
        }

    }

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
            
            let store = Store<T1.State>(state: .start)
            let result = try await T1.run(
                state: \.state,
                host: store,
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
            let store = Store<T1.State>(state: .start)
            let proxy = T1.Proxy()
            var out1: [Int] = []
            var out2: [String] = []
            
            try proxy.send(.start)
            try proxy.send(.cancel)
            _ = try await T1.run(
                state: \.state,
                host: store,
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

    struct EffectTests {
        
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
            
            typealias Effect = Oak.Effect<Event, Env>

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
        @Test func testTypes() async throws {
            print(type(of: T1.State.self))
            print(type(of: T1.Event.self))
            print(type(of: T1.TransducerOutput.self))
            print(type(of: T1.Effect.self))
            print(type(of: T1.Env.self))
            print(type(of: T1.Proxy.self))
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
            print(result)
            #expect(result == (2, "finished"))
        }
        
        @MainActor
        @Test func testResultRunWithExternalState() async throws {
            let proxy = T1.Proxy()
            try proxy.send(.start)
            try proxy.send(.cancel)
            
            let store = Store<T1.State>(state: .start)
            let result = try await T1.run(
                state: \.state,
                host: store,
                proxy: proxy,
                env: T1.Env()
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
                env: T1.Env(),
                out: Callback { @MainActor output in
                    out1.append(output.0)
                    out2.append(output.1)
                }
            )
            
            #expect(out1 == [0, 2])
            #expect(out2 == ["running", "finished"])
        }
        
        @MainActor
        @Test func testOutputRunWithExternalState() async throws {
            let store = Store<T1.State>(state: .start)
            let proxy = T1.Proxy()
            var out1: [Int] = []
            var out2: [String] = []
            
            try proxy.send(.start)
            try proxy.send(.cancel)
            _ = try await T1.run(
                state: \.state,
                host: store,
                proxy: proxy,
                env: T1.Env(),
                out: Callback { @MainActor output in
                    out1.append(output.0)
                    out2.append(output.1)
                }
            )
            
            #expect(out1 == [0, 2])
            #expect(out2 == ["running", "finished"])
        }
        
    }

}

extension TransducerTests {
    
    struct Examples {
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
            
            typealias Effect = Oak.Effect<Event, Env>

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
