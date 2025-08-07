// Oak - CompositeTransducerProtocol.swift
//
// Defines the protocol for composite transducers that combine multiple transducers
// using different composition strategies.

/// A type representing a composite event for parallel composition.
///
/// This enum allows either component transducer to receive events independently.
public enum CompositeEvent<EventA, EventB> {
    /// An event for the first component transducer
    case eventA(EventA)
    
    /// An event for the second component transducer
    case eventB(EventB)
}

/// A type representing composite output from parallel composition.
///
/// This enum allows tracking which component produced an output.
public enum CompositeOutput<OutputA, OutputB> {
    /// Output from the first component transducer
    case outputA(OutputA)
    
    /// Output from the second component transducer
    case outputB(OutputB)

    public typealias Output = (OutputA, OutputB)
}

/// A type representing the composite state of two transducers.
///
/// This struct combines the states of both component transducers and
/// implements Terminable by considering both component states.
public struct CompositeState<StateA: Terminable, StateB: Terminable>: Terminable {
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


public protocol CompositeProxy<ProxyA, ProxyB> {
    associatedtype ProxyA: TransducerProxyInternal
    associatedtype ProxyB: TransducerProxyInternal

    init()

    var proxyA: ProxyA { get }
    var proxyB: ProxyB { get }
}

public struct SyncCallback<Value>: Subject {
    let fn: (sending Value, isolated any Actor) async throws -> Void

    /// Initialises a `Callback` value with the given isolated throwing closure.
    ///
    /// - Parameter fn: An async throwing closure which will be called when `Self`
    /// receives a value via its `send(_:)` function.
    public init(_ fn: @escaping (Value, isolated any Actor) async throws -> Void) {
        self.fn = fn
    }

    /// Send a value to `Self` which calls its callback clouser with the argument `value`.
    /// - Parameter value: The value which is used as the argument to the callback closure.
    /// - Parameter isolated: The "system actor" where this function is being called on.
    public func send(
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
public protocol CompositeTransducerProtocol: BaseTransducer where Proxy: CompositeProxy<TransducerA.Proxy, TransducerB.Proxy> {
    /// The first component transducer
    associatedtype TransducerA: BaseTransducer
    
    /// The second component transducer
    associatedtype TransducerB: BaseTransducer
    
    /// The marker type for the composition strategy (parallel or sequential)
    associatedtype CompositionTypeMarker: CompositionType

    /// The type of the environment used by the transducers. Usually, a
    // product type that contains shared resources or configuration for 
    // both transducers. Default is `Void` assuming that no transducer 
    // has an environment.
    associatedtype Env = Void
}

/// Extension providing default implementation for parallel composition
extension CompositeTransducerProtocol where 
    CompositionTypeMarker: ParallelComposition,
    State == CompositeState<TransducerA.State, TransducerB.State>,
    Event == CompositeEvent<TransducerA.Event, TransducerB.Event>,
    Output == CompositeOutput<TransducerA.Output, TransducerB.Output>.Output,
    Env == Void,
    TransducerA.Output: Sendable,
    TransducerB.Output: Sendable,
    TransducerA: Transducer,
    TransducerB: Transducer {
    
    /// Run the parallel composite transducer
    ///
    /// In parallel composition, either component can receive events independently.
    /// The run function dispatches the event to the appropriate component.
    @discardableResult
    public static func run(
        initialState: State,
        proxy: Proxy = .init(),
        output: some Subject<CompositeOutput<TransducerA.Output, TransducerB.Output>>,
        isolated: isolated any Actor
    ) async throws -> Output {

        let transducerTaskA = Task {
            _ = isolated
            return try await TransducerA.run(
                initialState: initialState.stateA,
                proxy: proxy.proxyA,
                output: SyncCallback { value, isolated in
                    try await output.send(.outputA(value), isolated: isolated)
                }       
            )
        }

        let transducerTaskB = Task {
            _ = isolated
            return try await TransducerB.run(
                initialState: initialState.stateB,
                proxy: proxy.proxyB,
                output: SyncCallback { value, isolated in
                    try await output.send(.outputB(value), isolated: isolated)
                }
            )
        }

        // Wait for both tasks to complete
        async let outputA = transducerTaskA.value
        async let outputB = transducerTaskB.value

        return try await (outputA, outputB)
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
    State == CompositeState<TransducerA.State, TransducerB.State>,
    Event == TransducerA.Event,
    Output == TransducerB.Output,
    Env == Void,
    TransducerA: Transducer,
    TransducerB: Transducer {

        // TODO: implement sequential composition
    
}
