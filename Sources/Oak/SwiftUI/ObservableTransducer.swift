#if canImport(Observation)
import Observation

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@Observable
@MainActor
public final class ObservableTransducer<State, Proxy>: @MainActor TransducerActor where Proxy: TransducerProxy {
    
    public typealias Input = Proxy.Input
        
    struct TransducerCancelledError: Error {}
    
    public typealias Storage = UnownedReferenceKeyPathStorage<ObservableTransducer, State>
    
    private(set) public var state: State

    @ObservationIgnored
    public let proxy: Proxy
    
    @ObservationIgnored
    private var task: Task<Void, any Error>?
    

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
        ) -> Task<Void, any Error>
    ) {
        self.proxy = proxy
        self.state = initialState
        let transducerTask = runTransducer(
            .init(host: self, keyPath: \.state),
            proxy,
            MainActor.shared
        )
        self.task = transducerTask
        
        // Handle task completion to set task to nil when it finishes naturally
        Task { [weak self] in
            do {
                _ = try await transducerTask.value
            } catch {
                // Task was cancelled or failed, which is expected in many cases
            }
            // Set task to nil when completed (successfully or with error)
            await MainActor.run { [weak self] in
                self?.task = nil
            }
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
    
    deinit {
        task?.cancel()
    }
}

#else
#endif
