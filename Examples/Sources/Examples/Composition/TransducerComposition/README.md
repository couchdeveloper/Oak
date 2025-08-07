# Transducer Composition in Oak

This directory contains examples of how to compose transducers in the Oak framework using a generic protocol extension approach.

## Overview

Composition is a powerful technique for building complex systems from smaller, simpler parts. The `ComposableTransducer` implementation demonstrates how to compose two transducers into a new composite transducer, allowing you to build more complex state machines by combining simpler ones.

## Types of Composition

The implementation supports several composition strategies:

1. **Parallel Composition**: Both transducers run concurrently, processing events independently
2. **Sequential Composition**: The second transducer starts after the first one completes, potentially using the output of the first as input
3. **Custom Composition**: Allows for specialized composition with user-defined behavior

## Implementing Composition

The implementation provides:

1. A protocol extension for `BaseTransducer` that adds a `compose` method
2. A generic `CompositeTransducer` struct that handles the actual composition
3. Support for combining states, events, and outputs of the component transducers

## Examples

### Basic Usage

```swift
// Define two simple transducers
enum CounterTransducer: Transducer { /* ... */ }
enum TextTransducer: Transducer { /* ... */ }

// Compose them into a new transducer type
typealias ComposedTransducer = CompositeTransducer<CounterTransducer, TextTransducer>

// Create initial state and proxy
let initialState = ComposedTransducer.State(
    stateA: CounterTransducer.State(count: 0),
    stateB: TextTransducer.State(text: "")
)
let proxy = ComposedTransducer.Proxy()

// Run the composite transducer
let finalOutput = try await ComposedTransducer.run(
    initialState: initialState,
    proxy: proxy,
    output: outputCallback
)
```

### Using the Extension Method

```swift
// Create a composite transducer type using the extension method
let composedTransducerType = CounterTransducer.compose(
    with: TextTransducer.self,
    compositionType: .parallel
)
```

## Benefits of Composition

1. **Reusability**: Compose existing transducers to create new functionality
2. **Separation of Concerns**: Each transducer can focus on its specific responsibility
3. **Incremental Development**: Build complex state machines by adding one transducer at a time
4. **Testability**: Test component transducers independently before testing the composition

## Implementation Details

The implementation leverages Swift's generics and protocol extensions to create a type-safe composition mechanism. It handles the delegation of events and the combination of outputs, while maintaining the proper state management for each component transducer.

The composite transducer's proxy delegates to the proxies of the component transducers, forwarding events and managing cancellation appropriately.

## Future Enhancements

Potential enhancements to the composition mechanism could include:

1. Support for composing more than two transducers
2. Enhanced sequential composition with better output-to-input mapping
3. Support for conditional composition based on runtime state
4. Performance optimizations for specific composition patterns

See the example code in `TransducerCompositionExample.swift` for detailed usage examples.
