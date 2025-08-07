# Oak Composition Examples

This folder contains examples of compositional patterns for Oak transducers.

## Actor-less Composition

The `ActorLessComposition.swift` example demonstrates how to compose multiple transducers without using actors, leveraging the `BaseTransducer` protocol as a type container for composition.

### Key Concepts

1. **Type Composition Patterns**
   - **State**: Product type (struct) combining component states
   - **Event**: Sum type (enum) for routing events to appropriate sub-transducers
   - **Output**: Sum type (enum) for preserving the source of outputs

2. **Proxy Composition**
   - Delegates operations to sub-proxies
   - Composes input and auto-cancellation types
   - Preserves isolation and error handling

3. **Run Function Pattern**
   - Creates output subjects for each sub-transducer
   - Runs sub-transducers concurrently
   - Waits for completion and composes final output

4. **Benefits of This Approach**
   - Independent evolution of component transducers
   - Reuse of existing transducer logic
   - Separation of concerns between state management and composition
   - Type-safe composition

### Implementation Observations

1. **Leaf Transducers** (A and B in the example)
   - Simple and focused on specific state management
   - Conform to `Transducer` protocol with `update` function

2. **Composite Transducer** (TransducerC in the example)
   - Conforms to `BaseTransducer` which only requires type definitions
   - No need to implement an `update` function
   - Delegates to component transducers through `run`

3. **Proxy Implementation**
   - Currently requires manual implementation
   - Could benefit from a generic helper for common composition patterns

4. **Output Handling**
   - Sum types work well for preserving the source of outputs
   - Forwarding outputs requires careful handling of isolation

## Potential Improvements

Based on our exploration, we've identified several potential improvements for Oak's composition capabilities:

1. **Generic Composition Helpers**
   ```swift
   // Conceptual example of what could be added to Oak
   struct ComposedProxy<A: TransducerProxy, B: TransducerProxy>: TransducerProxy {
       // Generic implementation for any two proxies
   }
   
   func compose<A: Transducer, B: Transducer>(
       _ a: A.Type, 
       _ b: B.Type
   ) -> some BaseTransducer {
       // Return a composed transducer
   }
   ```

2. **Swift Macros**
   - Could generate the boilerplate for composition
   - Would reduce the risk of errors in manual composition

3. **Special Composition Types**
   - Sequential composition (chaining transducers)
   - Parallel composition (as demonstrated)
   - Hierarchical composition (state machines within state machines)

4. **Stream Handling**
   - Current example doesn't implement the `stream` property of the proxy
   - A generic implementation would need to merge streams from sub-proxies

## Usage Recommendations

1. **When to Use Composition**
   - When you have reusable transducer components
   - When different parts of your state machine have different concerns
   - When you want to break down complex state management into simpler pieces

2. **Composition vs. Single Transducer**
   - Use composition when parts of your state are logically separate
   - Use a single transducer when state updates are tightly coupled

3. **Testing Composed Transducers**
   - Test each component transducer independently
   - Test the composition with integration tests

## Conclusion

Oak's design principles support composition well, even without relying on actors. The type system and protocol-based approach create a solid foundation for building complex, composable state machines. With some additional helper utilities, Oak could make composition even more straightforward and less error-prone.
