import Testing
import Oak

@testable import struct Oak.Effect
@testable import struct Oak.Proxy
@testable import class Oak.Context

struct EffectTests {
    
    @MainActor
    @Test
    func testMultipleEffectsEffect() async throws {
        enum Event: Equatable { case ping(Int), terminate }
        struct Env {}
        let effect = Effect<Event, Env>.effects(
            .event(.ping(0)),
            .event(.ping(1)),
            .event(.ping(2))
        )
        let proxy = Proxy<Event>()
        effect.invoke(with: Env(), proxy: proxy, context: .init())
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
}
