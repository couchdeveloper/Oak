import Testing
import Foundation
import Oak

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@TestGlobalActor
@Test
func benchmarkAction() async throws {
    enum BenchmarkAction: EffectTransducer {
        struct State: Terminable {
            var count: Int = 0
            let maxCount: Int
            var isTerminal: Bool { count >= maxCount }
        }
        
        enum Event { case start, tick }

        typealias Output = Void
        typealias Env = Void

        static func update(_ state: inout State, event: Event) -> Self.Effect? {
            switch event {
            case .start:
                return Effect { _, _ in   // calling `Effect(isolatedAction:)` - this is bit faster than `Effect(action:)`
                    return .tick
                }
                
            case .tick:
                state.count += 1
                if !state.isTerminal {
                    return Effect { env, _ in
                        return .tick
                    }
                } else {
                    return nil
                }
            }
        }
    }
    
    let clock = ContinuousClock() // Or SuspendingClock

    func logTime(duration: ContinuousClock.Duration, function: String = #function) {
        print("\(function) Time elaspsed = \(duration)")
    }

    let startInstant = clock.now
    defer {
        let elaspsedTime = clock.now - startInstant
        logTime(duration: elaspsedTime)
        #expect(elaspsedTime < .milliseconds(1))
    }

    try await BenchmarkAction.run(
        initialState: .init(maxCount: 1_000),
        proxy: .init(initialEvent: .start),
        env: Void()
    )
}


@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@TestGlobalActor
@Test
func benchmarkActionWithOutput() async throws {
    enum T: EffectTransducer {
        struct State: Terminable {
            var count: Int = 0
            let maxCount: Int
            var isTerminal: Bool { count >= maxCount }
        }
            
        enum Event { case start, tick }

        typealias Output = Int
        typealias Env = Void

        static func update(_ state: inout State, event: Event) -> (Self.Effect?, Int) {
            switch event {
            case .start:
                return (Effect { _, _ in .tick }, 0)
                
            case .tick:
                state.count += 1
                if !state.isTerminal {
                    return (Effect { _, _ in .tick }, state.count)
                } else {
                    return (nil, state.count)
                }
            }
        }
    }

    let clock = ContinuousClock() // Or SuspendingClock

    func logTime(duration: ContinuousClock.Duration, function: String = #function) {
        print("\(function) Time elaspsed = \(duration)")
    }

    let startInstant = clock.now
    defer {
        let elaspsedTime = clock.now - startInstant
        logTime(duration: elaspsedTime)
        #expect(elaspsedTime < .milliseconds(2))
    }
    _ = try await T.run(
        initialState: .init(maxCount: 1_000),
        proxy: .init(initialEvent: .start),
        env: Void(),
        output: Callback { _ in }
    )
}

