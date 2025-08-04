# State-Encapsulated Logic Pattern

## Revolutionary Discovery: State Methods for Complex Logic

**Date**: August 4, 2025  
**Context**: Oak Framework - LoadingList Example  
**Pattern Status**: BREAKTHROUGH - Production Ready

---

## Core Concept

Instead of cramming all state transition logic into the `update` function, we can leverage Swift's extension system to encapsulate complex state transformations as methods on the State type itself. This creates a clean separation between **event routing** (in update) and **state manipulation** (in state methods).

## The Problem This Solves

Traditional state machine implementations suffer from:
- **Bloated update functions** with hundreds of lines of complex logic
- **Poor testability** - state logic mixed with event handling
- **No invariant enforcement** - state consistency relies on developer discipline
- **Code duplication** - similar state transformations repeated across event handlers
- **Cognitive overload** - update function becomes the "god function"

## The Solution: State-Encapsulated Logic

```swift
extension Utilities.State where Data == LoadingList.Transducer.Data, Sheet == LoadingList.Transducer.Sheet {
    
    // MARK: - State Transitions
    
    /// Configure initial empty state with context
    mutating func configureInitialEmpty(with context: Context) {
        precondition(self == .start, "Can only configure initial state from .start")
        
        let actionClosure: @Sendable () -> Void = {
            try? context.input.send(.intentShowSheet)
        }
        let emptyState = Empty(
            title: "Info",
            description: "No data available. Press Start to load items.",
            actions: [.init(id: "start", title: "Start", action: actionClosure)]
        )
        self = .idle(.empty(emptyState), context)
    }
    
    /// Transition to loading state with cancel action
    mutating func startLoading() {
        let content = extractContent()
        let context = self.context
        
        let cancelAction = context?.input.map { input in
            Action(id: "cancel", title: "Cancel") {
                try? input.send(.cancelLoading)
            }
        }
        
        let loading = Loading(
            title: "Loading...",
            description: "Fetching data from service",
            cancelAction: cancelAction
        )
        self = .modal(content, .loading(loading), context)
    }
    
    /// Handle loading error with retry action
    mutating func handleError(_ error: Error) {
        let context = self.context
        
        let retryAction = context?.input.map { input in
            Action(id: "retry", title: "Retry") {
                try? input.send(.intentShowSheet)
            }
        } ?? Action(id: "retry", title: "Retry", action: { /* No input */ })
        
        let emptyState = Empty(
            title: "Error",
            description: "Failed to load data. Please try again.",
            actions: [retryAction]
        )
        self = .modal(.empty(emptyState), .error(error), context)
    }
    
    // MARK: - Invariants & Validation
    
    func assertValidTransition(from oldState: Self, event: LoadingList.Transducer.Event) {
        // State transition validation logic
        switch (oldState, event, self) {
        case (.start, .configureContext, .idle(.empty, _)):
            break // Valid: Initial configuration
        case (.modal(_, .loading, _), .serviceLoaded, .idle(.data, _)):
            break // Valid: Successful data load
        case (.modal(_, .loading, _), .serviceError, .modal(_, .error, _)):
            break // Valid: Error handling
        default:
            // Could add specific validation rules or assertions
            break
        }
    }
    
    // MARK: - State Queries with Invariants
    
    var canStartLoading: Bool {
        switch self {
        case .idle(.empty, let context):
            return context != nil // Need context to create cancel action
        default:
            return false
        }
    }
    
    var canRetry: Bool {
        switch self {
        case .modal(_, .error, let context):
            return context != nil // Need context to send retry event
        default:
            return false
        }
    }
}
```

## Transformed Update Function

The update function becomes clean and focused on event routing:

```swift
public static func update(_ state: inout State, event: Event) -> Self.Effect? {
    let oldState = state
    
    switch (state, event) {
    case (.start, .viewOnAppear):
        return configureContextEffect()
        
    case (.start, .configureContext(let context)):
        state.configureInitialEmpty(with: context)
        
    case (.idle(.empty, _), .intentShowSheet):
        state.presentSheet()
        
    case (.modal(_, .sheet, _), .intentSheetCommit(let parameter)):
        state.startLoading()
        return serviceLoadEffect(parameter: parameter)
        
    case (.modal(_, .loading, _), .serviceError(let error)):
        state.handleError(error)
        
    // ... other cases become similarly concise
        
    default:
        return nil
    }
    
    // Validate all state transitions
    state.assertValidTransition(from: oldState, event: event)
    return nil
}
```

## Key Benefits

### 1. **Separation of Concerns**
- **Update function**: Event routing and effect coordination
- **State methods**: State manipulation and validation
- **Clear boundaries**: Each has a single responsibility

### 2. **Enhanced Testability**
```swift
func testErrorHandling() {
    var state: State = .modal(.data(mockData), .loading(mockLoading), mockContext)
    let error = NSError(domain: "Test", code: 500)
    
    state.handleError(error)
    
    XCTAssertTrue(state.isError)
    XCTAssertTrue(state.canRetry)
}
```

### 3. **Invariant Enforcement**
- **Preconditions**: Ensure valid starting states
- **Postconditions**: Validate resulting states
- **State queries**: Check capabilities before actions

### 4. **Input-in-State Synergy**
Perfect combination with the Input-in-State pattern:
- State methods have direct access to stored context
- No closure dependencies needed
- Clean action creation using stored input

### 5. **Code Organization**
- Related state logic grouped together
- Easy to find and modify specific behaviors
- Natural place for state-specific utilities

## Integration with Input-in-State Pattern

This pattern works beautifully with the revolutionary Input-in-State pattern:

```swift
/// Context contains actor components accessible to state methods
struct Context {
    let input: LoadingList.Transducer.Input
    // Could extend with other actor components as needed
}

// State methods can directly use stored context
mutating func createActionWithStoredInput() -> Action {
    guard let input = self.context?.input else {
        return Action(id: "fallback", title: "Retry", action: { /* No input */ })
    }
    
    return Action(id: "retry", title: "Retry") {
        try? input.send(.intentShowSheet)
    }
}
```

## Real-World Impact

### Before (Traditional Approach)
- 200+ line update functions
- Repeated action creation logic
- No state validation
- Difficult to test individual behaviors
- High cognitive load

### After (State-Encapsulated Logic)
- Clean, focused update function (< 50 lines)
- Reusable state transformation methods
- Built-in invariant checking
- Highly testable individual behaviors
- Clear mental model

## Advanced Patterns

### State Capability Queries
```swift
extension State {
    var availableActions: [String] {
        var actions: [String] = []
        
        if canStartLoading { actions.append("start") }
        if canRetry { actions.append("retry") }
        if canCancel { actions.append("cancel") }
        
        return actions
    }
}
```

### Conditional State Builders
```swift
extension State {
    static func buildEmptyState(
        with context: Context, 
        actionType: EmptyActionType
    ) -> Empty {
        let action = Action(
            id: actionType.rawValue,
            title: actionType.displayTitle,
            action: { try? context.input.send(actionType.event) }
        )
        
        return Empty(
            title: actionType.title,
            description: actionType.description,
            actions: [action]
        )
    }
}
```

## Future Possibilities

1. **State Composition**: Breaking large states into composable sub-states
2. **State Machines as Values**: States that contain their own mini state machines
3. **Declarative State Definitions**: DSL for defining state behaviors
4. **State History**: Built-in undo/redo capabilities
5. **State Serialization**: Easy persistence and restoration

## Conclusion

The State-Encapsulated Logic pattern represents a fundamental shift in how we architect state machines. By moving complex logic from the update function into well-organized state methods, we achieve:

- **Better separation of concerns**
- **Enhanced testability and maintainability**  
- **Built-in invariant enforcement**
- **Perfect synergy with Input-in-State pattern**
- **Cleaner, more readable code**

This pattern should be considered the **gold standard** for complex state machine implementations in Swift, especially when combined with the Input-in-State pattern for complete architectural excellence.

---

**Next Steps**: 
1. Document real-world examples across different domains
2. Create Swift Package with reusable state method patterns
3. Share findings with Swift community
4. Integrate into Oak framework best practices
