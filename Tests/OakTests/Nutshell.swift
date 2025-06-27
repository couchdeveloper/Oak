
enum Nutshell {
    
    protocol ContextProtocol {
        typealias ID = Int
        typealias UID = Int
        
        init()
        
        func removeCompleted(id: some Hashable & Sendable, uid: UID)
        
        func register(id: some Hashable & Sendable, uid: UID, task: Task<Void, Never>)

        func register(uid: UID, task: Task<Void, Never>) -> TaskID

        // func cancelAll()
        
        func cancelTask(id: TaskID)
        
        func uniqueID() -> ID
        func uniqueUID() -> UID
    }
    
    protocol Proxyable<Event>: Sendable {
        associatedtype Event
        func send(_ event: Event) throws
        func terminate(failure: Swift.Error?)
    }

    protocol P: SendableMetatype {
        associatedtype Env
        associatedtype Event
        associatedtype Output
        associatedtype Proxy: Nutshell.Proxyable<Event>
        associatedtype Context: Nutshell.ContextProtocol, SendableMetatype

        static func compute() -> Output
    }
    
    struct Effect<T: P> {
        typealias Env = T.Env
        typealias Context = T.Context
        typealias Proxy = T.Proxy

        private let f: (sending Env, Proxy, sending Context, isolated any Actor) -> Void

        private init(f: sending @escaping (sending Env, Proxy, sending Context, isolated any Actor) -> Void) {
            self.f = f
        }
        
        private static func make(f: sending @escaping (sending Env, Proxy, sending Context, isolated any Actor) -> Void) -> Effect {
            .init(f: f)
        }


        func invoke(
            with env: sending Env,
            proxy: Proxy,
            context: sending Context,
            isolated: isolated any Actor = #isolation
        ) {
            f(env, proxy, context, isolated)
        }
        
        public init(
            id: some Hashable & Sendable,
            operation: sending @escaping (
                Env,
                Proxy
            ) async throws -> Void,
            priority: TaskPriority? = nil
        ) {
            self.f = { env, proxy, context, isolated in
                let uid = context.uniqueUID()
                let task = Task.init(priority: priority) {
                    do {
                        try await operation(env, proxy)
                    } catch is CancellationError {
                    } catch {
                        proxy.terminate(failure: error)
                    }
                    T.removeCompletedTask(
                        id: id,
                        uid: uid,
                        context: context,
                        isolated: isolated
                    )
                }
                context.register(id: id, uid: uid, task: task)
            }
        }
        
        init(
            _ action: sending @escaping (Env, Proxy) -> Void,
        ) {
            self.f = { env, proxy, _, _ in
                action(env, proxy)
            }
        }

        public static func action(
            _ action: sending @escaping (Env, Proxy) -> Void
        ) -> Effect {
            .init(action)
        }

        init(
            _ effects: sending [Effect],
        ) {
            self.f = { env, proxy, context, isolated in
                effects.forEach { e in
                    e.f(env, proxy, context, isolated)
                }
            }
        }

        static func effects(
            _ effects: sending [Effect]
        ) -> Effect {
            .init(effects)
        }
    }
    
}

// MARK: - Implementation

extension Nutshell.P where Output == Nutshell.Effect<Self> {
    
    @MainActor
    static func run(
        proxy: Proxy,
        env: Env
    ) async throws {
        var context = Context()
        for _ in 0..<10 {
            try await Task.sleep(nanoseconds: 1_000)
            let effect = compute()
            effect.invoke(with: env, proxy: proxy, context: context)
        }
    }
}

extension Nutshell.P {
    static func removeCompletedTask(
        id: some Hashable & Sendable,
        uid: Context.UID,
        context: Context,
        isolated: isolated (any Actor) = #isolation
    ) {
        context.removeCompleted(id: id, uid: uid)
    }
}


extension Nutshell {
    
    struct TaskID: @unchecked Sendable, Hashable {
        private let wrapped: AnyHashable
        
        init(_ wrapped: some Hashable & Sendable) {
            self.wrapped = .init(wrapped)
        }
    }

    final class Context: ContextProtocol {
        func removeCompleted(id: some Hashable & Sendable, uid: UID) {
        }
        
        func register(id: some Hashable & Sendable, uid: UID, task: Task<Void, Never>) {
        }
        
        func register(uid: UID, task: Task<Void, Never>) -> TaskID {
            .init(uid)
        }
        
        func cancelTask(id: TaskID) {
        }
        
        func uniqueID() -> ID {
            id += 1
            return id
        }
        
        func uniqueUID() -> UID {
            uid += 1
            return uid
        }
        
        init() {}
        private var id: Int = 0
        private var uid: Int = 0
    }
}

extension Nutshell {
    struct Proxy<Event>: Proxyable {
        func send(_ event: Event) throws {}
        func terminate(failure: Swift.Error?) {}
    }
}

// MARK: - Example
extension Nutshell {
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
                print("Hello, World!")
            }
        }
    }
    
}
