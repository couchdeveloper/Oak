#if canImport(Observation)
import Observation

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@Observable
@MainActor
public final class ObservableTransducer<Transducer>: @MainActor TransducerActor
where Transducer: BaseTransducer {
    public typealias State = Transducer.State
    public typealias Event = Transducer.Event
    public typealias Output = Transducer.Output
    public typealias Proxy = Transducer.Proxy
    public typealias Input = Transducer.Proxy.Input
    public typealias Content = Never
    public typealias Storage = UnownedReferenceKeyPathStorage<ObservableTransducer, State>

    public struct Completion: @MainActor Oak.Completable {
        public typealias Value = Output
        public typealias Failure = Error

        let f: (Result<Value, Failure>) -> Void

        public init(_ onCompletion: @escaping (Result<Value, Failure>) -> Void) {
            f = onCompletion
        }
        public func completed(with result: Result<Value, Failure>) {
            f(result)
        }

        func before(g: @escaping (Result<Value, Failure>) -> Result<Value, Failure>) -> Self {
            .init { result in
                self.f(g(result))
            }
        }
    }

    struct TransducerCancelledError: Error {}

    private(set) public var state: State

    @ObservationIgnored
    public let proxy: Proxy

    @ObservationIgnored
    private var task: Task<Void, Never>?

    /// Required initializer from TransducerActor protocol.
    ///
    /// This is the only method we need to implement. All convenience initializers come from
    /// protocol extensions.
    ///
    /// > Warning: Do not call this initialiser directly. It's called internally by the other initialiser
    /// overloads.
    ///
    /// - Parameters:
    ///   - initialState: The start state of the transducer.
    ///   - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///   - completion: A completion handler which will be called once when the transducer
    ///   finishes, providing a `Result` that contains either the successful output value or
    ///   an error if the transducer failed.
    ///   - runTransducer: A closure which will be immediately called when the actor will be initialised.
    ///   It starts the transducer which runs in a Swift Task.
    ///   - content: A closure for creating content based on state and input.
    ///
    public init(
        initialState: State,
        proxy: Proxy,
        completion: Completion? = nil,
        runTransducer: (Storage, Proxy, Completion, isolated any Actor) -> Task<Void, Never>,
        content: (State, Input) -> Content
    ) {
        self.proxy = proxy
        self.state = initialState
        let completion =
            completion?.before { [weak self] in
                self?.task = nil
                return $0
            } ?? Completion { [weak self] _ in self?.task = nil }

        self.task = runTransducer(
            .init(host: self, keyPath: \.state),
            proxy,
            completion,
            MainActor.shared
        )
    }

    public var isRunning: Bool {
        task != nil
    }

    public func cancel() {
        if let task = task {
            proxy.cancel()
            task.cancel()
        }
        task = nil
    }

    // TODO: in future, for Swift 6.2+ use isolated deinit.
    deinit {
        task?.cancel()
    }

}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
extension ObservableTransducer where Transducer: EffectTransducer {
    public typealias Env = Transducer.Env
}

#else
#endif
