import Testing
import Oak

@testable import struct Oak.Effect
@testable import struct Oak.Proxy
@testable import class Oak.Context

struct EffectTests {
    
    @MainActor
    @Test
    func testMultipleEffectsEffect() async throws {
        
        enum Example: Transducer {
            enum State: Terminable { case start }
            enum Event: Equatable { case ping(Int), terminate }
            typealias Effect = Oak.Effect<Self>
            struct Env {}
            static func update(_ state: inout State, event: Event) -> Effect? { nil }
        }
        
        let effect = Example.Effect.effects([
            .event(.ping(0)),
            .event(.ping(1)),
            .event(.ping(2))
        ])
        let proxy = Example.Proxy()
        effect.invoke(with: Example.Env(), proxy: proxy, context: .init())
        try proxy.send(.terminate)
        
        var events: [Int] = []
        for try await event in proxy.input {
            switch event {
            case .event(.ping(let value)):
                events.append(value)
            case .event(.terminate):
                proxy.continuation.finish()
            case .control:
                break
            }
        }
        let expected = [0, 1, 2]
        #expect(events == expected)
    }
    
    
    @available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
    @MainActor
    @Test
    func testMultipleEffectsEffect2() async throws {
        
        enum Example: Transducer {
            enum State: Terminable { case start }
            enum Event: Equatable { case ping(Int), terminate }
            typealias Effect = Oak.Effect<Self>
            struct Env {}
            static func update(_ state: inout State, event: Event) -> Effect? { nil }
        }
        
        let effect = Example.Effect.effects([
            .event(.ping(0), after: .milliseconds(3), tolerance: .milliseconds(0)),
            .event(.ping(1), after: .milliseconds(2), tolerance: .milliseconds(0)),
            .event(.ping(2), after: .milliseconds(1), tolerance: .milliseconds(0)),
            .event(.terminate, after: .milliseconds(5), tolerance: .milliseconds(0)),
        ])
        let proxy = Example.Proxy()
        effect.invoke(with: Example.Env(), proxy: proxy, context: .init())
        
        var events: [Int] = []
        for try await event in proxy.input {
            switch event {
            case .event(.ping(let value)):
                events.append(value)
            case .event(.terminate):
                proxy.continuation.finish()
            case .control:
                break
            }
        }
        let expected = [2, 1, 0]
        #expect(events == expected)
    }
}
