// Oak - CompositeTransducerProtocol.swift
//
// Defines the protocol for composite transducers that combine multiple transducers
// using different composition strategies.

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
    let fn: (Value, isolated any Actor) async throws -> Void

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
        _ value: Value,
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
extension CompositeTransducerProtocol
where
    CompositionTypeMarker: ParallelComposition,
    State == ProductTypeState<TransducerA.State, TransducerB.State>,
    Event == SumTypeEvent<TransducerA.Event, TransducerB.Event>,
    Output == SumTypeOutput<TransducerA.Output, TransducerB.Output>.Tuple,
    Env == ProductTypeEnv<TransducerA.Env, TransducerB.Env>,
    TransducerA.Output: Sendable,
    TransducerB.Output: Sendable,
    TransducerA: BaseTransducer,
    TransducerB: BaseTransducer
{

    /// Run the parallel composite transducer
    ///
    /// In parallel composition, both component transducers run concurrently.
    /// Events are dispatched to the appropriate component based on the SumTypeEvent type.
    @discardableResult
    public static func run<P>(
        initialState: State,
        proxy: P,
        env: Env,
        output: some Subject<SumTypeOutput<TransducerA.Output, TransducerB.Output>>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output
    where P: ProductTypeProxy, P.ProxyA == TransducerA.Proxy, P.ProxyB == TransducerB.Proxy {
        // Create output subjects that wrap the outputs from each component
        let outputA = SyncCallback<TransducerA.Output> { valueA, actor in
            guard actor === systemActor else {
                return
            }
            nonisolated(unsafe) let output = output
            try await output.send(.outputA(valueA), isolated: actor)
        }
        let outputB = SyncCallback<TransducerB.Output> { valueB, actor in
            guard actor === systemActor else {
                return
            }
            nonisolated(unsafe) let output = output
            try await output.send(.outputB(valueB), isolated: actor)
        }

        // Set up task to run transducer A
        let transducerTaskA = Task {
            return try await TransducerA.run(
                initialState: initialState.stateA,
                proxy: proxy.proxyA,
                env: env.envA,
                output: outputA,
                systemActor: systemActor
            )
        }

        // Set up task to run transducer B
        let transducerTaskB = Task {
            return try await TransducerB.run(
                initialState: initialState.stateB,
                proxy: proxy.proxyB,
                env: env.envB,
                output: outputB,
                systemActor: systemActor
            )
        }

        // Wait for both tasks to complete
        do {
            // We need to explicitly annotate these with 'let' to ensure proper task behavior
            let outputAValue = try await transducerTaskA.value
            let outputBValue = try await transducerTaskB.value
            return (outputAValue, outputBValue)
        } catch {
            // Ensure all tasks are cancelled if there's an error
            throw error
        }
    }

    /// Provides the initial output for the composite transducer
    ///
    /// For parallel composition, if either component has an initial output,
    /// we will return that (with preference to transducer A if both have initial outputs)
    public static func initialOutput(
        initialState: State
    ) -> SumTypeOutput<TransducerA.Output, TransducerB.Output>? {
        if let outputA = TransducerA.initialOutput(initialState: initialState.stateA) {
            return .outputA(outputA)
        } else if let outputB = TransducerB.initialOutput(initialState: initialState.stateB) {
            return .outputB(outputB)
        }
        return nil
    }
}
