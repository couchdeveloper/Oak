#if canImport(SwiftUI) && canImport(Observation)
import SwiftUI
import Observation

/// A generic model class that manages the lifecycle and state of a transducer
/// outside of SwiftUI views.
///
/// `TransducerModel` provides an Observable interface to transducer state while
/// managing the underlying transducer lifecycle. Unlike `TransducerView`, this
/// model can be used independently of view hierarchies and provides manual
/// control over transducer startup and termination.
///
/// The model uses a separate state holder pattern to avoid reference cycles
/// when the transducer's long-running task captures the model.
///
/// ## Usage Example
/// 
/// ### Direct Usage with Extensions (Recommended)
/// ```swift
/// // Define type-constrained extensions for your transducers
/// @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
/// extension TransducerModel where State == CounterTransducer.State, Proxy == CounterTransducer.Proxy {
///     static func effectCounter() -> TransducerModel<CounterTransducer.State, CounterTransducer.Proxy> {
///         TransducerModel(
///             of: CounterTransducer.self,
///             initialState: CounterTransducer.initialState,
///             proxy: CounterTransducer.Proxy(),
///             env: CounterTransducer.Env()
///         )
///     }
///
///     func increment() {
///         try? input.send(.increment)
///     }
/// }
/// 
/// // Use directly in SwiftUI - no wrapper classes needed!
/// struct CounterView: View {
///     @State private var counter = TransducerModel.effectCounter()
///     
///     var body: some View {
///         VStack {
///             Text("Count: \(counter.state.value)")  // Direct state access
///             Button("Increment") { counter.increment() }
///             Button("Start") { counter.start() }
///         }
///     }
/// }
/// ```
///
/// `TransducerModel` is `@Observable`, so it automatically publishes state changes
/// to SwiftUI. No need for wrapper classes or `@ObservableObject`!
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@Observable
@MainActor
public final class TransducerModel<State: Terminable, Proxy: TransducerProxy> {

    public typealias Input = Proxy.Input

    /// The current state of the transducer (read-only)
    ///
    /// The state can only be modified by the transducer's update function
    /// to maintain FSM invariants. To reset the transducer, use `restart(with:)`.
    public var state: State {
        stateHolder.state
    }

    /// Whether the transducer is currently running
    public private(set) var isRunning = false

    /// Input interface for sending events to the transducer
    public var input: Input {
        proxy.input
    }
    
    @ObservationIgnored private let proxy: Proxy
    @ObservationIgnored private let stateHolder: StateHolder
    @ObservationIgnored private var task: Task<Void, Error>?
    @ObservationIgnored private let runTransducer: (
        StateHolder, 
        Proxy
    ) -> Void 

    /// Cancels the transducer.
    ///
    /// This forcibly terminates the running transducer task but does not
    /// modify the state.
    ///
    /// If the transducer is not running, this method does nothing.
    public func cancel() {
        guard isRunning else {
            return
        }
        task?.cancel()
        task = nil
        isRunning = false
    }
    
    /// Restarts the transducer with a new initial state.
    ///
    /// This method forcibly terminates the current transducer (if running) and
    /// restarts it with the provided initial state. This is the safe way to
    /// "reset" a transducer while maintaining FSM invariants.
    ///
    /// - Parameter newInitialState: The new initial state to restart with.
    public func restart(with newInitialState: State) {
        cancel()
        stateHolder.state = newInitialState
        start()
    }
    
    // MARK: - Initializers for Transducer
    
    /// Initializes a model with a `Transducer` that produces no output.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The initial state of the transducer.
    ///   - proxy: The proxy to use for the transducer.
    public convenience init<T: Transducer>(
        of type: T.Type = T.self,
        initialState: State,
        proxy: Proxy
    ) where T.State == State, T.Proxy == Proxy, T.Output == Void {
        self.init(
            initialState: initialState,
            runTransducer: { stateHolder, proxy in
                Task {
                    do {
                        _ = try await T.run(
                            state: \StateHolder.state,
                            host: stateHolder,
                            proxy: proxy
                        )
                    } catch {
                        logger.error("Transducer (\(proxy.id)) failed: \(error)")
                    }
                }
            },
            proxy: proxy
        )
    }
    
    /// Initializes a model with a `Transducer` that produces output.
    ///
    /// - Parameters:
    ///   - type: The type of the transducer.
    ///   - initialState: The initial state of the transducer.
    ///   - proxy: The proxy to use for the transducer.
    ///   - output: A subject to receive the transducer's output.
    public convenience init<T: Transducer>(
        of type: T.Type = T.self,
        initialState: State,
        proxy: Proxy,
        output: some Subject<T.Output>
    ) where T.State == State, T.Proxy == Proxy {
        self.init(
            initialState: initialState,
            runTransducer: { stateHolder, proxy in
                Task {
                    do {
                        _ = try await T.run(
                            state: \StateHolder.state,
                            host: stateHolder,
                            proxy: proxy,
                            output: output
                        )
                    } catch {
                        logger.error("Transducer (\(proxy.id)) failed: \(error)")
                    }
                }
            },
            proxy: proxy
        )
    }
        
    // MARK: - Initializers for EffectTransducer

    /// Initializes a model with an `EffectTransducer` that produces effects and output.
    ///
    /// - Parameters:
    ///   - type: The type of the effect transducer.
    ///   - initialState: The initial state of the transducer.
    ///   - proxy: The proxy to use for the transducer.
    ///   - env: The environment for the transducer.
    ///   - output: A subject to receive the transducer's output.
    public convenience init<T: EffectTransducer>(
        of type: T.Type = T.self,
        initialState: State,
        proxy: Proxy,
        env: T.Env,
        output: some Subject<T.Output>
    ) where T.State == State, T.Proxy == Proxy, T.TransducerOutput == (T.Effect?, T.Output) {
        self.init(
            initialState: initialState,
            runTransducer: { stateHolder, proxy in
                Task {
                    do {
                        _ = try await T.run(
                            storage: ReferenceKeyPathStorage(
                                host: stateHolder,
                                keyPath: \StateHolder.state
                            ),
                            proxy: proxy,
                            env: env,
                            output: output
                        )
                    } catch {
                        logger.error("EffectTransducer (\(proxy.id)) failed: \(error)")
                    }
                }
            },
            proxy: proxy
        )
    }
    
    /// Initializes a model with an `EffectTransducer` that produces only effects.
    ///
    /// - Parameters:
    ///   - type: The type of the effect transducer.
    ///   - initialState: The initial state of the transducer.
    ///   - proxy: The proxy to use for the transducer.
    ///   - env: The environment for the transducer.
    public convenience init<T: EffectTransducer>(
        of type: T.Type = T.self,
        initialState: State,
        proxy: Proxy,
        env: T.Env
    ) where T.State == State, T.Proxy == Proxy, T.TransducerOutput == T.Effect?, T.Output == Void {
        self.init(
            initialState: initialState,
            runTransducer: { stateHolder, proxy in
                Task {
                    do {
                        _ = try await T.run(
                            storage: ReferenceKeyPathStorage(
                                host: stateHolder,
                                keyPath: \StateHolder.state
                            ),
                            proxy: proxy,
                            env: env
                        )
                    } catch {
                        logger.error("EffectTransducer (\(proxy.id)) failed: \(error)")
                    }
                }
            },
            proxy: proxy
        )
    }

    // MARK: - Internal

    // Separate state holder to avoid reference cycles
    @Observable
    internal final class StateHolder {
        var state: State
        
        init(state: State) {
            self.state = state
        }
    }
    
    /// Starts the transducer.
    ///
    /// If the transducer is already running, this method does nothing.
    /// The transducer will run until it reaches a terminal state or is stopped.
    internal func start() {
        guard !isRunning else { return }
        
        isRunning = true
        
        // Capture necessary values to avoid capturing self
        let runTransducer = self.runTransducer
        let stateHolder = self.stateHolder
        let proxy = self.proxy
        
        // Start the transducer in a separate task
        task = Task { @MainActor in
            runTransducer(stateHolder, proxy)
        }
    }
        
    // MARK: - Private
    
    private init(
        initialState: State,
        runTransducer: @escaping (StateHolder, Proxy) -> Void,
        proxy: Proxy
    ) {
        self.stateHolder = StateHolder(state: initialState)
        self.runTransducer = runTransducer
        self.proxy = proxy
        
        isRunning = true
        
        // Start the transducer in a separate task
        // Caution: do not capture `self` in the task's
        // closure!
        let stateHolder = self.stateHolder
        task = Task { @MainActor in
            runTransducer(stateHolder, proxy)
        }
    }
    
    // MARK: - Lifecycle
    
    deinit {
        task?.cancel()
    }
    
}

#endif
