// Example: Actor-less composition of two transducers using sum types and composed proxy
// Oak Example - ActorLessComposition.swift
//
// This example demonstrates how to compose multiple transducers without using actors.
// It uses the BaseTransducer protocol which only requires type definitions without
// requiring an update function, making it ideal for composition.
//
// Key composition patterns demonstrated:
// - Using sum types for events and outputs
// - Composing state from sub-transducer states
// - Creating a custom proxy that delegates to sub-proxies
// - Implementing a run function that delegates to sub-transducer run functions
// - Forwarding outputs from sub-transducers to the parent transducer's output

import Foundation
import Oak


// MARK: - Transducer Definitions
enum A: Transducer {
    struct State: NonTerminal { var count: Int }
    enum Event { case increment }
    typealias Output = Int

    static func update(_ state: inout State, event: Event) -> Int {
        switch event {
        case .increment:
            state.count += 1
            return state.count
        }
    }
}

enum B: Transducer {
    struct State: NonTerminal { var count: Int }
    enum Event { case increment }
    typealias Output = Int

    static func update(_ state: inout State, event: Event) -> Int {
        switch event {
        case .increment:
            state.count += 1
            return state.count
        }
    }
}

// MARK: - Composition Example
/// `TransducerC` demonstrates composition of two transducers (`A` and `B`) without using actors.
/// It conforms to `BaseTransducer` rather than `Transducer` since it doesn't need to implement
/// an `update` function - it delegates to the component transducers instead.
///
/// This pattern allows for:
/// - Independent evolution of component transducers
/// - Reuse of existing transducer logic
/// - Separation of concerns between state management and composition
/// - Building complex state machines from simpler building blocks
struct TransducerC: BaseTransducer {
    struct State: NonTerminal {
        var stateA: A.State
        var stateB: B.State
    }   

    enum Event {
        case eventA(A.Event)
        case eventB(B.Event)    
    }

    enum Output {
        case outputA(A.Output)
        case outputB(B.Output)
    }

    struct Proxy: TransducerProxy {

        typealias Event = TransducerC.Event

        let proxyA: A.Proxy
        let proxyB: B.Proxy

        init() {
            self.proxyA = A.Proxy()
            self.proxyB = B.Proxy()
        }   

        init(proxyA: A.Proxy, proxyB: B.Proxy) {
            self.proxyA = proxyA
            self.proxyB = proxyB
        }     

        typealias Stream = AsyncThrowingStream<Event, Swift.Error> 

        var stream: Stream {
            fatalError("not implemented") // Implement stream logic if needed
        }   

        func checkInUse() throws(TransducerError) {
            try proxyA.checkInUse()
            try proxyB.checkInUse()
        }

        func cancel(with error: Swift.Error?) {
            proxyA.cancel(with: error)
            proxyB.cancel(with: error)
        }

        func finish() {
            proxyA.finish()
            proxyB.finish()
        }   

        // Unique identifier for the proxy
        public let id: UUID = UUID()

        struct Input {
            let inputA: A.Proxy.Input
            let inputB: B.Proxy.Input   
        }

        var input: Input {
            Input(inputA: proxyA.input, inputB: proxyB.input)
        }   

        public final class AutoCancellation: Sendable, Equatable {
            public static func == (lhs: AutoCancellation, rhs: AutoCancellation) -> Bool {
                lhs.id == rhs.id
            }

            let autoCancellationA: A.Proxy.AutoCancellation
            let autoCancellationB: B.Proxy.AutoCancellation
            let id: Proxy.ID

            init(proxy: Proxy) {
                autoCancellationA = proxy.proxyA.autoCancellation
                autoCancellationB = proxy.proxyB.autoCancellation
                id = proxy.id
            }
        }   

        public var autoCancellation: AutoCancellation {
            AutoCancellation(proxy: self)
        }    

    }

    static func run(
        initalState: State,
        proxy: Proxy,
        output: some Subject<Output> & Sendable
    ) async throws -> Output {
        // Create output subjects for A and B that forward to the main output
        let subjectA = Oak.Callback<A.Output> { value in
            // Forward A's output to the main output subject
            // In a real implementation, handle the try/await properly
        }
        
        let subjectB = Oak.Callback<B.Output> { value in
            // Forward B's output to the main output subject
            // In a real implementation, handle the try/await properly
        }

        // Run A and B concurrently
        async let resultA = A.run(
            initialState: initalState.stateA,
            proxy: proxy.proxyA,
            output: subjectA
        )
        async let resultB = B.run(
            initialState: initalState.stateB,
            proxy: proxy.proxyB,
            output: subjectB
        )

        // Wait for both to finish
        let (finalA, _) = try await (resultA, resultB)

        // Compose final output (choose how to represent termination)
        // Here, just return the last output from A as an example
        return .outputA(finalA)
    }
    
}

// MARK: - Example Usage
func example() async {
    // Create initial state for TransducerC
    let initialState = TransducerC.State(
        stateA: A.State(count: 0),
        stateB: B.State(count: 0)
    )
    
    // Create proxy for TransducerC
    let proxy = TransducerC.Proxy()
    
    // Create a callback to handle outputs
    let outputCallback = Oak.Callback<TransducerC.Output> { output in
        switch output {
        case .outputA(let value):
            print("Output from A: \(value)")
        case .outputB(let value):
            print("Output from B: \(value)")
        }
    }
    
    // Create a task to run the transducer
    Task {
        do {
            let finalOutput = try await TransducerC.run(
                initalState: initialState,
                proxy: proxy,
                output: outputCallback
            )
            
            print("Final output: \(finalOutput)")
        } catch {
            print("Error: \(error)")
        }
    }
    
    // Send some events to the composed transducer
    Task {
        // Simulate some interaction with the transducer
        try? await Task.sleep(for: .milliseconds(100))
        
        // Send an event to A (adjust according to your actual API)
        try? proxy.proxyA.input.send(.increment)
        
        // Send an event to B (adjust according to your actual API)
        try? proxy.proxyB.input.send(.increment)
        
        // Let them run for a bit
        try? await Task.sleep(for: .milliseconds(500))
        
        // Signal completion
        proxy.finish()
    }
}

