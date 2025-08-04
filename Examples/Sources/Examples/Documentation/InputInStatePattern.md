# Input-in-State Pattern Documentation

## Overview

This document describes a powerful pattern for Oak transducers where the `update` function gains access to actor components (like `Input`, `Proxy`, etc.) by storing them directly in the state, delivered via action effects.

## The Pattern

### Core Concept

Instead of relying on encapsulated action closures that capture the `Input` from the environment, the update function can receive and store the `Input` directly in the state. This eliminates the need for closure-based actions and makes the update function more self-contained.

### Implementation Details

1. **State Structure Enhancement**:
   ```swift
   enum State {
       case start
       case idle(Content, Context?)
       case modal(Content, Modal, Context?)
       
       struct Context {
           let input: Input  // Actor components stored here
       }
   }
   ```

2. **Context Delivery Effect**:
   ```swift
   static func configureContextEffect() -> Self.Effect {
       Effect(isolatedAction: { env, isolated in
           return .configureContext(State.Context(input: env.input))
       })
   }
   ```

3. **State Transitions with Context**:
   ```swift
   case (.start, .viewOnAppear):
       return configureContextEffect()
       
   case (.start, .configureContext(let context)):
       return configureEmptyStateEffect(withInput: context.input)
   ```

4. **Direct Input Usage in Update Function**:
   ```swift
   case (.modal(let content, .loading(_), let context), .cancelLoading):
       // Update function can directly use stored input
       if let input = context?.input {
           // Direct access to input without closures
       }
   ```

## Benefits

### 1. **Self-Contained Update Function**
- The update function becomes more autonomous
- No need for external closure capturing
- Cleaner separation between effects and state logic

### 2. **No Retain Cycles**
- Oak's `Input` is designed to avoid retain cycles
- Safe to store in state without memory management issues
- Can be used across different isolation contexts

### 3. **Testability**
- State becomes more predictable and testable
- Actor components are explicitly part of the state structure
- Easy to mock or substitute for testing

### 4. **Type Safety**
- Full compile-time checking of actor component access
- Clear ownership model for actor components
- Explicit handling of cases where components might not be available

## Usage Pattern

### Initialization Flow
1. App starts → `viewOnAppear` event
2. Effect delivers context → `configureContext` event  
3. Update function stores context in state
4. Subsequent updates can use stored input directly

### Action Creation with Stored Input
```swift
let cancelAction: State.Action? = {
    if let input = context?.input {
        return State.Action(
            id: "cancel", 
            title: "Cancel",
            action: { try? input.send(.cancelLoading) }
        )
    }
    return nil
}()
```

## Architectural Advantages

### 1. **Explicit Dependencies**
- Actor components are visible in the state structure
- Clear about what components are available at each state
- No hidden dependencies through closure captures

### 2. **Flexible Component Access**
- Can potentially store other actor components (Proxy, Env, etc.)
- Extensible pattern for future actor component needs
- Context can be enhanced without changing the core pattern

### 3. **Clean Effect Design**
- Effects focus on their specific responsibilities
- No need to create action closures in effects
- Simpler effect implementations

## Pattern Evolution

This pattern represents an evolution from:

**Before**: Closure-based actions with captured environment
```swift
let action = Action(title: "Start") {
    try? env.input.send(.intentShowSheet)
}
```

**After**: Direct input access from stored context
```swift
if let input = state.context?.input {
    let action = Action(title: "Start") {
        try? input.send(.intentShowSheet)
    }
}
```

## Key Insight

> The update function, while having no direct knowledge of the actor during its definition, can gain access to actor components through the very mechanism it controls: the effect-event cycle. This creates a powerful feedback loop where the update function can enhance its own capabilities through the state it manages.

This pattern demonstrates the sophisticated design of Oak's architecture, where effects can serve not just as side-effect executors, but as conduits for enhancing the update function's access to the broader system.
