// Oak - CompositeTransducerProtocol.swift
//
// Defines the protocol for composite transducers that combine multiple transducers
// using different composition strategies.
#if false
/// A type representing a composite event for parallel composition.
///
/// This enum allows either component transducer to receive events independently.
public enum SumTypeEvent<EventA, EventB> {
    /// An event for the first component transducer
    case eventA(EventA)
    
    /// An event for the second component transducer
    case eventB(EventB)
}

/// A type representing composite output from parallel composition.
///
/// This enum allows tracking which component produced an output.
public enum SumTypeOutput<OutputA, OutputB> {
    /// Output from the first component transducer
    case outputA(OutputA)
    
    /// Output from the second component transducer
    case outputB(OutputB)

    public typealias Tuple = (OutputA, OutputB)
}

/// A type representing the composite state of two transducers.
///
/// This struct combines the states of both component transducers and
/// implements Terminable by considering both component states.
public struct ProductTypeState<StateA: Terminable, StateB: Terminable>: Terminable {
    /// The state of the first component transducer
    public var stateA: StateA
    
    /// The state of the second component transducer
    public var stateB: StateB
    
    /// Creates a new composite state
    public init(stateA: StateA, stateB: StateB) {
        self.stateA = stateA
        self.stateB = stateB
    }
    
    /// Returns true if either component state is terminal
    public var isTerminal: Bool {
        stateA.isTerminal || stateB.isTerminal
    }
}

/// A type representing the composite environment for two transducers.
///
/// This struct combines the environments of both component transducers,
/// allowing each transducer to access its own environment.
public struct ProductTypeEnv<EnvA, EnvB> {
    /// The environment for the first component transducer
    public var envA: EnvA
    
    /// The environment for the second component transducer
    public var envB: EnvB
    
    /// Creates a new composite environment
    public init(envA: EnvA, envB: EnvB) {
        self.envA = envA
        self.envB = envB
    }
}

/// Protocol for a composite proxy that manages proxies for multiple transducers
public protocol ProductTypeProxy<ProxyA, ProxyB> {
    /// The proxy type for the first component transducer
    associatedtype ProxyA: TransducerProxy
    
    /// The proxy type for the second component transducer
    associatedtype ProxyB: TransducerProxy

    /// Initialize a new composite proxy
    init()

    /// Access to the proxy for the first component transducer
    var proxyA: ProxyA { get }
    
    /// Access to the proxy for the second component transducer
    var proxyB: ProxyB { get }
}

/// A simple callback-based Subject implementation
struct SyncCallback<Value>: Subject {
    let fn: (sending Value, isolated any Actor) async throws -> Void

    /// Initialises a `Callback` value with the given isolated throwing closure.
    ///
    /// - Parameter fn: An async throwing closure which will be called when `Self`
    /// receives a value via its `send(_:)` function.
    init(_ fn: @escaping (Value, isolated any Actor) async throws -> Void) {
        self.fn = fn
    }

    /// Send a value to `Self` which calls its callback clouser with the argument `value`.
    /// - Parameter value: The value which is used as the argument to the callback closure.
    /// - Parameter isolated: The "system actor" where this function is being called on.
    func send(
        _ value: sending Value,
        isolated: isolated any Actor = #isolation
    ) async throws {
        try await fn(value, isolated)
    }
}

/// Protocol defining the requirements for a composite transducer.
///
/// A composite transducer combines two transducers together using a specific
/// composition strategy (parallel or sequential). This protocol provides a minimal
/// interface, and the actual behavior is implemented in extensions specific to 
/// each composition type.
public protocol CompositeTransducerProtocol: BaseTransducer {
    /// The first component transducer
    associatedtype TransducerA: BaseTransducer
    
    /// The second component transducer
    associatedtype TransducerB: BaseTransducer
    
    /// The marker type for the composition strategy (parallel or sequential)
    associatedtype CompositionTypeMarker: CompositionType

    /// The type of the environment used by the transducers.
    /// By default, this is a CompositeEnv combining the environments of both component transducers.
    /// Can be overridden to use a different environment type.
    associatedtype Env = ProductTypeEnv<TransducerA.Env, TransducerB.Env>
}

/// Extension providing default implementation for parallel composition
extension CompositeTransducerProtocol where 
    CompositionTypeMarker: ParallelComposition,
    State == ProductTypeState<TransducerA.State, TransducerB.State>,
    Event == SumTypeEvent<TransducerA.Event, TransducerB.Event>,
    Output == SumTypeOutput<TransducerA.Output, TransducerB.Output>.Tuple,
    TransducerA.Output: Sendable,
    TransducerB.Output: Sendable,
    TransducerA: BaseTransducer,
    TransducerB: BaseTransducer {
    
    /// Run the parallel composite transducer
    ///
    /// In parallel composition, both component transducers run concurrently.
    /// Events are dispatched to the appropriate component based on the SumTypeEvent type.
    @discardableResult
    public static func run<P>(
        storage: some Storage<State>,
        proxy: P,
        env: Env,
        output: some Subject<SumTypeOutput<TransducerA.Output, TransducerB.Output>>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output where P: ProductTypeProxy, P.ProxyA == TransducerA.Proxy, P.ProxyB == TransducerB.Proxy {
        // Get proxies from the composite proxy
        let proxyA = proxy.proxyA
        let proxyB = proxy.proxyB
        
        // Extract component environments
        let envA: TransducerA.Env
        let envB: TransducerB.Env
        
        // Create output subjects that wrap the outputs from each component
        let outputA = SyncCallback<TransducerA.Output> { valueA, actor in
            try await output.send(.outputA(valueA), isolated: actor)
        }
        let outputB = SyncCallback<TransducerB.Output> { valueB, actor in
            try await output.send(.outputB(valueB), isolated: actor)
        }
        
        // Set up task to run transducer A
        let transducerTaskA = Task {
            return try await TransducerA.run(
                storage: storage.value.stateA,
                proxy: proxyA,
                env: envA,
                output: outputA,
                systemActor: systemActor
            )
        }
        
        // Set up task to run transducer B
        let transducerTaskB = Task {
            return try await TransducerB.run(
                initialState: initialState.stateB,
                proxy: proxyB,
                env: envB,
                output: outputB,
                systemActor: systemActor
            )
        }
        
        // Set up event handling from main proxy to component proxies
        let eventDispatchTask = Task {
            do {
                // Process events from the proxy
                for try await event in Self.getStream(for: proxy) {
                    // Dispatch events based on the CompositeEvent type
                    switch event {
                    case .eventA(let eventA):
                        try await proxyA.input.send(eventA)
                    case .eventB(let eventB):
                        try await proxyB.input.send(eventB)
                    }
                }
            } catch {
                // If event processing fails, cancel both transducers
                transducerTaskA.cancel()
                transducerTaskB.cancel()
                throw error
            }
        }
        
        // Wait for both tasks to complete
        do {
            // We need to explicitly annotate these with 'let' to ensure proper task behavior
            let outputAValue = try await transducerTaskA.value
            let outputBValue = try await transducerTaskB.value
            
            // Clean up
            eventDispatchTask.cancel()
            
            return (outputAValue, outputBValue)
        } catch {
            // Ensure all tasks are cancelled if there's an error
            eventDispatchTask.cancel()
            proxyA.cancel(with: error)
            proxyB.cancel(with: error)
            throw error
        }
    }
    
    
    /// Provides the initial output for the composite transducer
    ///
    /// For parallel composition, if either component has an initial output,
    /// we will return that (with preference to transducer A if both have initial outputs)
    public static func initialOutput(initialState: State) -> CompositeOutput<TransducerA.Output, TransducerB.Output>? {
        if let outputA = TransducerA.initialOutput(initialState: initialState.stateA) {
            return .outputA(outputA)
        } else if let outputB = TransducerB.initialOutput(initialState: initialState.stateB) {
            return .outputB(outputB)
        }
        return nil
    }
}

/// Extension providing default implementation for sequential composition
extension CompositeTransducerProtocol where 
    CompositionTypeMarker: SequentialComposition,
    State == ProductTypeState<TransducerA.State, TransducerB.State>,
    Event == TransducerA.Event,
    Output == TransducerB.Output,
    TransducerA.Output: Sendable,
    TransducerB.Output: Sendable,
    TransducerA: EffectTransducer,
    TransducerB: EffectTransducer {
    
    /// Converts output from the first transducer to an event for the second transducer
    /// 
    /// This method should be overridden by concrete implementations to define how
    /// outputs from the first transducer are converted to events for the second transducer.
    public static func convertOutput(_ output: TransducerA.Output) -> TransducerB.Event? {
        // Default implementation returns nil - should be overridden by concrete types
        return nil
    }
    
    /// Run the sequential composite transducer
    ///
    /// In sequential composition, events are processed by the first transducer,
    /// and its outputs are converted to events for the second transducer.
    @discardableResult
    public static func run<P: ProductTypeProxy>(
        initialState: State,
        proxy: P,
        env: Env,
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output where P.ProxyA == TransducerA.Proxy, P.ProxyB == TransducerB.Proxy {
        // Get proxies from the composite proxy
        let proxyA = proxy.proxyA
        let proxyB = proxy.proxyB
        
        // Extract component environments
        let envA: TransducerA.Env
        let envB: TransducerB.Env
        
        if let compositeEnv = env as? ProductTypeEnv<TransducerA.Env, TransducerB.Env> {
            envA = compositeEnv.envA
            envB = compositeEnv.envB
        } else {
            // Default to empty environments if not a CompositeEnv
            // This handles the Void case safely
            envA = unsafeBitCast((), to: TransducerA.Env.self)
            envB = unsafeBitCast((), to: TransducerB.Env.self)
        }
        
        // Create a callback to convert outputs from transducer A to events for transducer B
        let bridgeAtoB = SyncCallback<TransducerA.Output> { valueA, actor in
            if let eventB = Self.convertOutput(valueA) {
                try await proxyB.send(eventB)
            }
        }
        
        // Run both transducers concurrently, connecting them via the bridge
        return try await withThrowingTaskGroup(of: Output.self) { group in
            // Start transducer A
            group.addTask {
                let outputA = SyncCallback<TransducerA.Output> { valueA, actor in
                    try await bridgeAtoB.send(valueA, isolated: actor)
                }
                
                _ = try await TransducerA.run(
                    initialState: initialState.stateA, 
                    proxy: proxyA,
                    env: envA,
                    output: outputA,
                    systemActor: systemActor
                )
                
                // This will never be reached in practice as transducer A runs until completion
                return unsafeBitCast((), to: Output.self)
            }
            
            // Start transducer B
            group.addTask {
                let result = try await TransducerB.run(
                    initialState: initialState.stateB, 
                    proxy: proxyB,
                    env: envB,
                    output: output,
                    systemActor: systemActor
                )
                
                return result
            }
            
            // Set up event handling from main proxy to component proxies
            group.addTask {
                do {
                    // Process events from the main proxy's stream
                    let stream = AsyncThrowingStream<Event, Swift.Error> { continuation in
                        Task {
                            do {
                                for try await event in proxy.stream {
                                    continuation.yield(event)
                                }
                                continuation.finish()
                            } catch {
                                continuation.finish(throwing: error)
                            }
                        }
                    }
                    
                    for try await event in stream {
                        // In sequential composition, all events go to the first transducer
                        try await proxyA.send(event)
                    }
                    
                    // Return dummy value if we complete normally
                    return unsafeBitCast((), to: Output.self)
                } catch {
                    // If event processing fails, propagate the error
                    throw error
                }
            }
            
            // Return the first result (should be from transducer B)
            if let result = try await group.next() {
                // Cancel all other tasks
                group.cancelAll()
                return result
            } else {
                // This should never happen with proper implementation
                throw TransducerError.unexpectedCompletion
            }
        }
        
        // Set up task to run transducer A
        let transducerTaskA = Task {
            return try await TransducerA.run(
                initialState: initialState.stateA,
                proxy: proxyA,
                output: bridgeAtoB
            )
        }
        
        // Set up task to run transducer B
        let transducerTaskB = Task {
            return try await TransducerB.run(
                initialState: initialState.stateB,
                proxy: proxyB,
                output: output
            )
        }
        
        // Set up event handling from main proxy to component proxies
        let eventDispatchTask = Task {
            do {
                // Process events from the main proxy's stream
                for try await event in proxy.stream {
                    // In sequential composition, all events go to the first transducer
                    try await proxy.proxyA.input.send(event)
                }
            } catch {
                // If event processing fails, cancel both transducers
                transducerTaskA.cancel()
                transducerTaskB.cancel()
                throw error
            }
        }
        
        // Wait for transducer B to complete - it produces our final output
        let result = try await transducerTaskB.value
        
        // Clean up
        eventDispatchTask.cancel()
        transducerTaskA.cancel()
        
        return result
    }
    
    /// Provides the initial output for the composite transducer
    ///
    /// For sequential composition, if the first transducer has an initial output
    /// that can be converted to an event for the second transducer, we process that
    /// event through the second transducer and return its output.
    public static func initialOutput(initialState: State) -> Output? {
        // Check if first transducer has initial output
        if let outputA = TransducerA.initialOutput(initialState: initialState.stateA),
           let eventB = Self.convertOutput(outputA) {
            // If it can be converted to an event for second transducer,
            // get the output from the second transducer for that event
            var stateB = initialState.stateB
            let result = TransducerB.update(&stateB, event: eventB)
            if case let (_, output) = result {
                return output
            }
        }
        
        // Otherwise, check if second transducer has initial output
        return TransducerB.initialOutput(initialState: initialState.stateB)
    }
}
#endif
