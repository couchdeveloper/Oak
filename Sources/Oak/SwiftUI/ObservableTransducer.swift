#if canImport(Observation)
import Observation

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@Observable
@MainActor
public final class ObservableTransducer<Transducer>: @MainActor TransducerActor where Transducer: BaseTransducer {
    public typealias State = Transducer.State
    public typealias Event = Transducer.Event
    public typealias Output = Transducer.Output
    public typealias Proxy = Transducer.Proxy
    public typealias Input = Transducer.Proxy.Input
    
    struct TransducerCancelledError: Error {}
    
    public typealias Storage = UnownedReferenceKeyPathStorage<ObservableTransducer, State>
    
    private(set) public var state: State

    @ObservationIgnored
    public let proxy: Proxy
    
    @ObservationIgnored
    private var task: Task<Void, Never>?
    
    /// Returns a transducer actor.
    ///
    /// > Caution: Do not call this initialiser directly. It's called internally by the other initialiser
    /// overloads.
    ///
    /// - Parameters:
    ///  - isolated: The isolation from the caller.
    ///  - initialState: The start state of the transducer.
    ///  - proxy: A proxy which will be associated to the transducer, or `nil` in which case the view
    ///   creates one.
    ///  - runTransducer: A closure which will be immediately called when the actor will be initialised.
    ///   It starts the transducer which runs in a Swift Task.
    ///
    public init(
        initialState: State,
        proxy: Proxy,
        runTransducer: (
            UnownedReferenceKeyPathStorage<ObservableTransducer, State>,
            Proxy,
            isolated any Actor
        ) -> Task<Void, Never>
    ) {
        self.proxy = proxy
        self.state = initialState
        let transducerTask = runTransducer(
            .init(host: self, keyPath: \.state),
            proxy,
            MainActor.shared
        )
        self.task = transducerTask
        Task { [weak self] in
            _ = await transducerTask.value
            self?.task = nil
        }
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
