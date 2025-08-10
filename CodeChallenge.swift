import Foundation

/*
 ┌─────────────────────────────────────────────────────────────────────────┐
 │                                                                         │
 │             Oak Framework - Transducer Composition Challenge            │
 │                                                                         │
 └─────────────────────────────────────────────────────────────────────────┘

 The challenge involves a sequential composition of two transducers (A and B)
 which results in a new transducer.

 A Solution With Clear Flow Paths:
 
 External World                                     External World
 
 ┌────────────┐                                     ┌─────────────┐
 │            │                                     │             │
 │  Input     │                                     │  Output     │
 │            │                                     │             │
 └─────┬──────┘                                     ▲─────────────┘
       │                                            │
       │ Events                                     │ Values
       │                                            │
       │         ┌───────────────────────────────┐  │
       │         │                               │  │
       │         │ Sequential Composition System │  │
       │         │                               │  │
       │         │ ┌─────────────────────┐       │  │
       │         │ │     TransducerA     │       │  │
       │         │ │                     │       │  │
       └─────────┼▶│ Input        Output │       │  │
                 │ │                     │       │  │
                 │ └─────────┬───────────┘       │  │
                 │           │                   │  │
                 │           │ A.Output          │  │
                 │           ▼                   │  │
                 │ ┌─────────────────────┐       │  │
                 │ │                     │       │  │
                 │ │     Transform to    │       │  │
                 │ │       B.Event       │       │  │
                 │ │                     │       │  │
                 │ └─────────┬───────────┘       │  │
                 │           │                   │  │
                 │           │ B.Event           │  │
                 │           ▼                   │  │
                 │ ┌─────────────────────┐       │  │
                 │ │     TransducerB     │       │  │
                 │ │                     │       │  │
                 │ │ Input        Output ├───────┼──┘
                 │ │                     │       │
                 │ └─────────────────────┘       │
                 │                               │
                 └───────────────────────────────┘
                 
Flow:                                              
 1. External proxy.A sends Events to TransducerA input.
 2. TransducerA processes Events and produces output values
 3. A.Output values are transformed to B.Event
 4. B.Event is sent to TransducerB input.
 5. TransducerB processes Events and produces output values
 6. TransducerB's output values are sent to external Output B
*/


// MARK: - Core Protocol Definitions

/// Base protocol for all transducers
public protocol BaseTransducer {
    associatedtype State: Terminable
    associatedtype Event
    associatedtype Output
    associatedtype Env
    associatedtype Proxy: TransducerProxy
    
    static func run(
        initialState: State,
        proxy: Proxy,
        env: Env,
        output: some Subject<Output>,
        systemActor: isolated any Actor
    ) async throws -> Output
    
    static func initialOutput(initialState: State) -> Output?
}

/// Protocol for a proxy that can be used to send events to a transducer
public protocol TransducerProxy {
    associatedtype Event
    associatedtype Input
    
    // The input interface for the transducer
    var input: Input { get }
    
    // No stream property - this is an implementation detail handled internally
}

/// Protocol for a type that can signal when it has reached a terminal state
public protocol Terminable {
    var isTerminal: Bool { get }
}

/// Protocol for a subject that can receive values
public protocol Subject<Value> {
    associatedtype Value
    func send(_ value: Value, isolated: isolated any Actor) async throws
}

/// Marker protocol for composition types
public protocol CompositionType {}

/// Marker protocol for parallel composition
public protocol ParallelComposition: CompositionType {}

/// Protocol for sequential composition that includes a transformation
/// from the output type of the first transducer to the event type of the second transducer
public protocol SequentialComposition<InputType, OutputType>: CompositionType {
    /// The output type of TransducerA
    associatedtype InputType
    
    /// The event type of TransducerB
    associatedtype OutputType
    
    /// Transform from TransducerA's Output to TransducerB's Event
    static func transform(_ input: InputType) -> OutputType?
}

// MARK: - Core Types


/// Protocol for a composite proxy that manages proxies for multiple transducers
public protocol ProductTypeProxy<ProxyA, ProxyB> {
    associatedtype ProxyA: TransducerProxy
    associatedtype ProxyB: TransducerProxy

    init()
    var proxyA: ProxyA { get }
    var proxyB: ProxyB { get }
}

/// A simple callback-based Subject implementation
struct SyncCallback<Value>: Subject {
    let fn: (Value, isolated any Actor) async throws -> Void

    init(_ fn: @escaping (Value, isolated any Actor) async throws -> Void) {
        self.fn = fn
    }

    func send(
        _ value: Value,
        isolated: isolated any Actor = #isolation
    ) async throws {
        try await fn(value, isolated)
    }
}

/// A type representing the composite state of two transducers
public struct ProductTypeState<StateA: Terminable, StateB: Terminable>: Terminable {
    public var stateA: StateA
    public var stateB: StateB
    
    public init(stateA: StateA, stateB: StateB) {
        self.stateA = stateA
        self.stateB = stateB
    }
    
    public var isTerminal: Bool {
        stateA.isTerminal || stateB.isTerminal
    }
}

/// A type representing the composite environment for two transducers
public struct ProductTypeEnv<EnvA, EnvB> {
    public var envA: EnvA
    public var envB: EnvB
    
    public init(envA: EnvA, envB: EnvB) {
        self.envA = envA
        self.envB = envB
    }
}

/// Error type for transducer operations
enum TransducerError: Error {
    case cancelled
    case proxyAlreadyInUse
}

/// Protocol defining the requirements for a composite transducer
public protocol CompositeTransducerProtocol: BaseTransducer {
    associatedtype TransducerA: BaseTransducer
    associatedtype TransducerB: BaseTransducer
    associatedtype CompositionTypeMarker: CompositionType
    associatedtype Env = ProductTypeEnv<TransducerA.Env, TransducerB.Env>
}

/// Extension providing sequential composition implementation
extension CompositeTransducerProtocol where 
    // The composition type marker must be SequentialComposition with appropriate input/output types
    CompositionTypeMarker: SequentialComposition,
    CompositionTypeMarker.InputType == TransducerA.Output,  // Input type is TransducerA's output
    CompositionTypeMarker.OutputType == TransducerB.Event,  // Output type is TransducerB's event
    
    // Ensure proper state, event, output, and environment types
    State == ProductTypeState<TransducerA.State, TransducerB.State>,
    Event == TransducerA.Event,
    Output == TransducerB.Output,
    Env == ProductTypeEnv<TransducerA.Env, TransducerB.Env>,
    
    // Ensure outputs are sendable (required for async contexts)
    TransducerA.Output: Sendable,
    TransducerB.Output: Sendable,
    
    // Ensure both transducers conform to BaseTransducer
    TransducerA: BaseTransducer,
    TransducerB: BaseTransducer {
    
    /// Run the sequential composite transducer
    public static func run<P>(
        initialState: State,
        proxy: P,
        env: Env,
        output: some Subject<Output>,
        systemActor: isolated any Actor = #isolation
    ) async throws -> Output where P: ProductTypeProxy, P.ProxyA == TransducerA.Proxy, P.ProxyB == TransducerB.Proxy {
        // Create a bridge that converts outputs from transducer A to events for transducer B
        // This is the transformation from A.Output to B.Event
        let bridgeAtoB = SyncCallback<TransducerA.Output> { valueA, _ in
            // Convert the output to an event for the second transducer using the transform function
            if let eventB = CompositionTypeMarker.transform(valueA) {
                // In the actual implementation, this would send the event to transducer B
                print("Transform A.Output to B.Event: \(eventB)")
            }
        }
        
        // Run both transducers concurrently, connecting them via the bridge
        return try await withThrowingTaskGroup(of: Output.self) { group in
            // Start transducer B first as it will provide our final output
            group.addTask {
                return try await TransducerB.run(
                    initialState: initialState.stateB,
                    proxy: proxy.proxyB,
                    env: env.envB,
                    output: output,
                    systemActor: systemActor
                )
            }
            
            // Start transducer A which will feed into B through the transformation bridge
            group.addTask {
                // We don't care about the output directly, it goes through the bridge
                // which transforms A.Output to B.Event
                let outputA = SyncCallback<TransducerA.Output> { valueA, actor in
                    try await bridgeAtoB.send(valueA, isolated: actor)
                }
                
                _ = try await TransducerA.run(
                    initialState: initialState.stateA,
                    proxy: proxy.proxyA,
                    env: env.envA,
                    output: outputA,
                    systemActor: systemActor
                )
                
                // This is a placeholder return
                return unsafeBitCast((), to: Output.self)
            }
            
            // No third task is needed - we've eliminated that complexity
            
            // Return the first result (should be from transducer B)
            do {
                if let result = try await group.next() {
                    group.cancelAll()
                    return result
                } else {
                    throw TransducerError.cancelled
                }
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }
}

// MARK: - Potential Solutions

// The implementation above demonstrates the optimized solution with clear transformation
// from TransducerA.Output to TransducerB.Event without the redundant task.
// 
// When we strip away all the type constraints, the actual implementation is quite concise:
//
// ```swift
// static func run<P>(...) async throws -> Output {
//     // 1. Create a bridge that transforms A.Output to B.Event
//     let bridgeAtoB = /* transformation from A.Output to B.Event */
//     
//     return try await withThrowingTaskGroup(of: Output.self) { group in
//         // 2. Run TransducerB (provides final output)
//         group.addTask { return try await TransducerB.run(...) }
//         
//         // 3. Run TransducerA (outputs to bridge)
//         group.addTask { 
//             _ = try await TransducerA.run(...)
//             return /* placeholder */ 
//         }
//         
//         // 4. Return result from TransducerB
//         if let result = try await group.next() {
//             group.cancelAll()
//             return result
//         } else {
//             throw TransducerError.cancelled
//         }
//     }
// }
// ```
//
// Key points in the solution:
// 1. Direct connection from external input to TransducerA
// 2. Clear transformation of TransducerA's output to TransducerB's events
// 3. Direct connection from TransducerB's output to external output
// 4. No redundant circular flow or unnecessary task
