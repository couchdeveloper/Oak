// Oak Example - TransducerCompositionExample.swift
//
// This example demonstrates how to compose transducers using both parallel and sequential composition
// strategies defined in the CompositeTransducerProtocol. It shows how to:
// - Create simple component transducers
// - Compose them using parallel composition
// - Compose them using sequential composition
// - Run the composed transducers

import Foundation
import Oak

// MARK: - Component Transducers

/// A simple counter transducer that increments a count when it receives an increment event
enum CounterTransducer: Transducer {
    struct State: NonTerminal {
        var count: Int
    }
    
    enum Event {
        case increment
        case reset
    }
    
    typealias Output = Int
    
    static func update(_ state: inout State, event: Event) -> Output {
        switch event {
        case .increment:
            state.count += 1
        case .reset:
            state.count = 0
        }
        return state.count
    }
    
    static func initialOutput(initialState: State) -> Output? {
        return initialState.count
    }
}

/// A transducer that takes numbers as input and doubles them
enum DoublerTransducer: Transducer {
    struct State: NonTerminal {
        // This transducer doesn't need internal state
    }
    
    // The event for this transducer is an integer
    typealias Event = Int
    
    // The output is also an integer, but doubled
    typealias Output = Int
    
    static func update(_ state: inout State, event: Event) -> Output {
        // Double the input value
        return event * 2
    }
}

// MARK: - Parallel Composition Example

/// A transducer that combines two counters in parallel
enum ParallelCountersTransducer: ParallelCompositeTransducer {
    typealias TransducerA = CounterTransducer
    typealias TransducerB = CounterTransducer
    typealias CompositionTypeMarker = DefaultParallelComposition
    
    // All other required types are defined by the ParallelCompositeTransducer protocol
}

// MARK: - Sequential Composition Example

/// A transducer that chains a counter and doubler in sequence
enum CounterThenDoublerTransducer: SequentialCompositeTransducer {
    typealias TransducerA = CounterTransducer
    typealias TransducerB = DoublerTransducer
    typealias CompositionTypeMarker = DefaultSequentialComposition
    
    // This method defines how the counter's output gets converted to the doubler's input
    static func convertOutput(_ output: TransducerA.Output) -> TransducerB.Event? {
        // The output of CounterTransducer is an Int, which is exactly what DoublerTransducer expects
        return output
    }
    
    // All other required types are defined by the SequentialCompositeTransducer protocol
}

// MARK: - Usage Examples

/// Demonstrates how to use both types of transducer composition
struct TransducerCompositionExample {
    /// Entry point function that demonstrates both composition types
    static func runExample() async throws {
        print("Starting Transducer Composition Example")
        
        try await demonstrateParallelComposition()
        try await demonstrateSequentialComposition()
        
        print("Finished Transducer Composition Example")
    }
    
    /// Demonstrates parallel composition of two counters
    static func demonstrateParallelComposition() async throws {
        print("
=== Parallel Composition Example ===")
        
        // Create a proxy for sending events to the parallel counters
        let proxy = ParallelCountersTransducer.Proxy()
        
        // Create a subject to observe outputs
        let output = Subject<ParallelCountersTransducer.Output>()
        
        // Subscribe to outputs
        output.subscribe { value in
            switch value {
            case .outputA(let countA):
                print("Counter A: \(countA)")
            case .outputB(let countB):
                print("Counter B: \(countB)")
            }
        }
        
        // Initial state with both counters at 0
        let initialState = CompositeState(
            stateA: CounterTransducer.State(count: 0),
            stateB: CounterTransducer.State(count: 0)
        )
        
        // Start the transducer in a task
        let task = Task {
            try await ParallelCountersTransducer.run(
                initialState: initialState,
                proxy: proxy,
                output: output
            )
        }
        
        // Send events to both counters
        proxy.send(.eventA(.increment))
        proxy.send(.eventB(.increment))
        proxy.send(.eventB(.increment))
        proxy.send(.eventA(.reset))
        proxy.send(.eventA(.increment))
        
        // Cancel the task to stop the transducer
        try await Task.sleep(nanoseconds: 1_000_000_000)
        task.cancel()
        try? await task.value
        
        print("Parallel composition demonstration completed")
    }
    
    /// Demonstrates sequential composition of a counter followed by a doubler
    static func demonstrateSequentialComposition() async throws {
        print("
=== Sequential Composition Example ===")
        
        // Create a proxy for sending events to the counter
        let proxy = CounterThenDoublerTransducer.Proxy()
        
        // Create a subject to observe outputs
        let output = Subject<CounterThenDoublerTransducer.Output>()
        
        // Subscribe to outputs
        output.subscribe { value in
            print("Doubled count: \(value)")
        }
        
        // Initial state with counter at 0
        let initialState = CompositeState(
            stateA: CounterTransducer.State(count: 0),
            stateB: DoublerTransducer.State()
        )
        
        // Start the transducer in a task
        let task = Task {
            try await CounterThenDoublerTransducer.run(
                initialState: initialState,
                proxy: proxy,
                output: output
            )
        }
        
        // Send events to the counter, which will then be doubled
        proxy.send(.increment) // Counter: 1 -> Doubler: 2
        proxy.send(.increment) // Counter: 2 -> Doubler: 4
        proxy.send(.increment) // Counter: 3 -> Doubler: 6
        proxy.send(.reset)     // Counter: 0 -> Doubler: 0
        proxy.send(.increment) // Counter: 1 -> Doubler: 2
        
        // Cancel the task to stop the transducer
        try await Task.sleep(nanoseconds: 1_000_000_000)
        task.cancel()
        try? await task.value
        
        print("Sequential composition demonstration completed")
    }
}
