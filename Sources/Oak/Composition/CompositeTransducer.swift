// Oak - CompositeTransducerProtocol.swift
//
// Defines the protocol for composite transducers that combine multiple transducers
// using different composition strategies.

import AsyncAlgorithms

/// Protocol defining the requirements for a composite transducer.
///
/// A composite transducer combines two transducers together using a specific
/// composition strategy (parallel or sequential). This protocol provides a minimal
/// interface, and the actual behavior is implemented in extensions specific to
/// each composition type.
public protocol CompositeTransducer: BaseTransducer, SendableMetatype {
    /// The first component transducer
    associatedtype TransducerA: BaseTransducer
    
    /// The second component transducer
    associatedtype TransducerB: BaseTransducer
    
    /// The marker type for the composition strategy (parallel or sequential)
    associatedtype CompositionTypeMarker: CompositionType

    /// The type of the environment used by the transducers.
    /// By default, this is a CompositeEnv combining the environments of both component transducers.
    /// Can be overridden to use a different environment type.
    associatedtype Env = ProductType<TransducerA.Env, TransducerB.Env>
}


extension ProductType where A: TransducerProxy, B: TransducerProxy {
    public init() {
        self.a = A()
        self.b = B()
    }
}

extension ProductType: Terminable where A: Terminable, B: Terminable {
    /// Returns true if either component state is terminal
    public var isTerminal: Bool {
        a.isTerminal || b.isTerminal
    }
}

extension AsyncChannel: Subject {
    public func send(_ value: sending Element, isolated: isolated any Actor) async throws {
        await self.send(value)
    }
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

/// Extension providing default implementation for parallel composition.
///
extension CompositeTransducer where
    CompositionTypeMarker: ParallelComposition,
    State == ProductType<TransducerA.State, TransducerB.State>,
    Event == ProductType<TransducerA.Event, TransducerB.Event>,
    Output == (TransducerA.Output, TransducerB.Output),
    Proxy: TransducerProxy<Event> & ProductTypeProtocol<TransducerA.Proxy, TransducerB.Proxy>,
    Env == ProductType<TransducerA.Env, TransducerB.Env>,
    TransducerA.Output: Sendable,
    TransducerB.Output: Sendable,
    TransducerA: BaseTransducer,
    TransducerB: BaseTransducer
{
    
    /// Run the parallel composite transducer.
    ///
    /// A variant of a parallel composition where input A and input B always match,
    /// and a pair of input A and input B produces a pair of output A and output B.
    ///
    /// The concrete type for parameter `proxy` and  the concrete type for
    /// parameter `output` needs to be provided by the caller.
    ///
    /// TODO: provide a type for proxy.
    @discardableResult
    public static func run(
        initialState: State,
        proxy: some TransducerProxy<Event> & ProductTypeProtocol<TransducerA.Proxy, TransducerB.Proxy>,
        env: Env,
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
        // We need an AsyncChannel, for each output, then zip them and
        // send them to parameter output
        let outputA = AsyncChannel<TransducerA.Output>()
        let outputB = AsyncChannel<TransducerB.Output>()
        
        let transducerTaskA = Task<TransducerA.Output, Error> {
            let _ = systemActor
            return try await TransducerA.run(
                initialState: initialState.a,
                proxy: proxy.a,
                env: env.a,
                output: outputA,
                systemActor: systemActor
            )
        }
        let transducerTaskB = Task<TransducerB.Output, Error> {
            let _ = systemActor
            return try await TransducerB.run(
                initialState: initialState.b,
                proxy: proxy.b,
                env: env.b,
                output: outputB,
                systemActor: systemActor
            )
        }
        let zipOutputTask = Task {
            let _ = systemActor
            for await outputValue in zip(outputA, outputB) {
                try await output.send(outputValue, isolated: systemActor)
            }
        }
        
        // Ensure all tasks are cancelled if there's an error
        defer {
            zipOutputTask.cancel()
            transducerTaskA.cancel()
            transducerTaskB.cancel()
        }

        do {
            let outputAValue = try await transducerTaskA.value
            let outputBValue = try await transducerTaskB.value
            return (outputAValue, outputBValue)
        } catch {
            throw error
        }
    }
    
    /// Provides the initial output for the composite transducer
    ///
    /// For parallel composition, if either component has an initial output,
    /// we will return that (with preference to transducer A if both have initial outputs)
    public static func initialOutput(initialState: State) -> SumType<TransducerA.Output, TransducerB.Output>? {
        if let outputA = TransducerA.initialOutput(initialState: initialState.a) {
            return .a(outputA)
        } else if let outputB = TransducerB.initialOutput(initialState: initialState.b) {
            return .b(outputB)
        }
        return nil
    }
}

/// Extension providing default implementation for sequential composition
extension CompositeTransducer where 
    // The composition type marker must be SequentialComposition with appropriate input/output types
    CompositionTypeMarker: SequentialComposition,
    CompositionTypeMarker.InputType == TransducerA.Output,  // Input type is TransducerA's output
    CompositionTypeMarker.OutputType == TransducerB.Event,  // Output type is TransducerB's event
    
    // Ensure proper state, event, output, and environment types
    State == ProductType<TransducerA.State, TransducerB.State>,
    Event == TransducerA.Event,
    Output == TransducerB.Output,
    Env == ProductType<TransducerA.Env, TransducerB.Env>,
    
    // Ensure outputs are sendable (required for async contexts)
    TransducerA.Output: Sendable,
    TransducerB.Output: Sendable,

    TransducerB.Proxy.Input: SyncSuspendingTransducerInput,
    TransducerB.Proxy.Input.Event == TransducerB.Event,

    // Ensure both transducers conform to BaseTransducer
    TransducerA: BaseTransducer,
    TransducerB: BaseTransducer {
    
    /// Run the sequential composite transducer
    ///
    /// In sequential composition, events are processed by the first transducer,
    /// and its outputs are converted to events for the second transducer.
    @discardableResult
    public static func run(
        initialState: State,
        proxy: ProductType<TransducerA.Proxy, TransducerB.Proxy>,
        env: Env,
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output {
        let transducerBTask = Task<Output, Error> {
            let _ = systemActor
            return try await TransducerB.run(
                initialState: initialState.b,
                proxy: proxy.b,
                env: env.b,
                output: output,
                systemActor: systemActor
            )
        }        
        let proxyBInput = proxy.b.input
        let transducerATask = Task<Void, Error> {
            let _ = systemActor
            _ = try await TransducerA.run(
                initialState: initialState.a,
                proxy: proxy.a,
                env: env.a,
                output: SyncCallback { value, systemActor in
                    if let eventB = CompositionTypeMarker.transform(value) {
                        await proxyBInput.send(eventB)
                    }
                },
                systemActor: systemActor
            )
        }
        
        do {
            // Wait for both tasks to complete or handle errors
            // The result from transducer B is our final output
            let result = try await transducerBTask.value
            
            // Cancel transducer A task if it's still running
            transducerATask.cancel()
            
            return result
        } catch {
            // If there's an error, cancel both tasks
            transducerATask.cancel()
            transducerBTask.cancel()
            throw error
        }
    }
    
    /// Provides the initial output for the composite transducer
    ///
    /// For sequential composition, if the first transducer has an initial output
    /// that can be converted to an event for the second transducer, we process that
    /// event through the second transducer and return its output.
    public static func initialOutput(initialState: State) -> Output? {
        // First, check if transducer A has an initial output
        if let outputA = TransducerA.initialOutput(initialState: initialState.a),
           let _ = CompositionTypeMarker.transform(outputA) {
            // Since we can't directly call update, we just return the initial output from B
            // In a real implementation, you would need to handle this differently
            return TransducerB.initialOutput(initialState: initialState.b)
        }
        
        // If A doesn't have an initial output or it can't be converted,
        // check if B has its own initial output
        return TransducerB.initialOutput(initialState: initialState.b)
    }
}
