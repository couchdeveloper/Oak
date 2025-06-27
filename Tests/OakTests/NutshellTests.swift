import Testing

struct NutshellTests {
    
    @MainActor
    @Test
    func testAction() async throws {
        
        enum Example: Nutshell.P {
            
            typealias Event = Int
            typealias Proxy = Nutshell.Proxy<Self.Event>
            typealias Context = Nutshell.Context
            typealias Effect = Nutshell.Effect<Self>
            typealias Output = Effect
            
            final class Env {
                var value = 0
            }
                        
            static func compute() -> Output {
                .action { env, proxy in
                    MainActor.shared.preconditionIsolated()
                    print("Hello, World!")
                }
            }
        }

        try await Example.run(proxy: .init(), env: .init())
        
        print("done")
    }
    
    
    @MainActor
    @Test
    func testMultipleEffects() async throws {
        
        enum Example: Nutshell.P {
            
            typealias Event = Int
            typealias Proxy = Nutshell.Proxy<Self.Event>
            typealias Context = Nutshell.Context
            typealias Effect = Nutshell.Effect<Self>
            typealias Output = Effect
            
            final class Env {
                var value = 0
            }
                        
            static func compute() -> Output {
                .effects([
                    .action { env, proxy in
                        MainActor.shared.preconditionIsolated()
                        print("Hello, World 1!")
                    },
                    .action { env, proxy in
                        MainActor.shared.preconditionIsolated()
                        print("Hello, World 2!")
                    },
                    .action { env, proxy in
                        MainActor.shared.preconditionIsolated()
                        print("Hello, World 3!")
                    },
                ])
            }
        }
        
        try await Example.run(proxy: .init(), env: .init())
        
        print("done")
    }

}
