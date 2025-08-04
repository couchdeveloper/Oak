# Usage Example

## Creating the Environment

```swift
// Create a proxy to get the input
let proxy = LoadingList.Transducer.Proxy()

// Simple service implementation
let env = LoadingList.Transducer.Env(
    service: { parameter in
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Return mock data based on parameter
        return LoadingList.Transducer.Data(
            items: [
                "Item 1 (\(parameter))",
                "Item 2 (\(parameter))", 
                "Item 3 (\(parameter))"
            ]
        )
    },
    input: proxy.input
)

// Or use a real service
let realEnv = LoadingList.Transducer.Env(
    service: { parameter in
        let url = URL(string: "https://api.example.com/data?param=\(parameter)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ServiceResponse.self, from: data)
        return LoadingList.Transducer.Data(items: response.items)
    },
    input: proxy.input
)
```

## Action Effects with Input Access

The key innovation is that action effects can now properly configure interactive UI elements:

```swift
// Action effects create pre-configured closures that capture input
static func configureEmptyStateEffect() -> Effect<LoadingList.Transducer> {
    Effect(isolatedAction: { env, isolated in
        let input = env.input  // Extract input reference first
        
        // Create @Sendable closure that captures input
        let actionClosure: @Sendable () -> Void = {
            try? input.send(.intentShowSheet)
        }
        
        // Return fully configured state with working actions
        return .configureEmpty(
            State.Empty(
                title: "Info",
                description: "No data available. Press Start to load items.",
                actions: [
                    .init(id: "start", title: "Start", action: actionClosure)
                ]
            )
        )
    })
}
```

## Encapsulated Action Handlers - Novel Pattern

Actions are encapsulated within state objects, creating more reliable UI binding:

```swift
// Actions live inside state, not in UI code
struct Empty {
    let title: String 
    let description: String
    let actions: [Action]  // Pre-configured actions
}

struct Action {
    let id: String
    let title: String
    let action: () -> Void  // Ready-to-use closure
}

// UI becomes purely declarative
ForEach(emptyState.actions) { action in
    Button(action.title, action: action.action)  // Can't bind wrong action
}
```

**Benefits of Encapsulated Actions:**
- **Eliminates binding errors**: No risk of connecting wrong closures to UI controls
- **Reliable behavior**: Same action always does the same thing
- **Easier reasoning**: Action behavior defined with state, not scattered in UI
- **Better testability**: Actions can be tested independently

## State Management

The transducer demonstrates several advanced patterns:

- **Start State Pattern**: Explicit `.start` state instead of `.idle(.empty(nil))`
- **Optional Associated Data**: `empty(Empty?)` distinguishes unconfigured vs configured
- **Environment Injection**: Contains both service function AND input reference
- **Type Safety**: All state transitions work with the correct `Data` type
- **Action Effects**: Can properly configure interactive UI elements with working event handlers
- **Encapsulated Actions**: UI actions are pre-configured within state objects

## Critical Error Handling

Proper distinction between recoverable and fatal errors:

```swift
// UI Actions: Use try? (recoverable - user can retry)
let actionClosure: @Sendable () -> Void = {
    try? input.send(.intentShowSheet)
}

// Service Effects: Use try (must terminate if buffer full)
static func serviceLoadEffect(parameter: String) -> Effect<LoadingList.Transducer> {
    Effect(isolatedOperation: { env, input, systemActor in
        do {
            let data = try await env.service(parameter)
            try input.send(.serviceLoaded(data))  // Critical - must not use try?
        } catch {
            try input.send(.serviceError(error))  // Critical - must not use try?
        }
    })
}
```

**Key Insight**: If buffer overflow prevents service completion events, the transducer should terminate rather than hang indefinitely.

## Benefits

1. **Start State Clarity**: Explicit `.start` state vs confusing nested nils
2. **Proper Dependency Injection**: Service and input both injected via environment
3. **Sendable Action Effects**: Proper @Sendable closure handling across isolation boundaries
4. **Encapsulated Action Handlers**: Actions pre-configured in state, eliminating UI binding errors
5. **Critical Error Handling**: Buffer overflow in service effects terminates transducer appropriately
6. **Working UI**: Interactive elements (buttons, sheets) can actually send events back
7. **Testability**: Easy to mock both service and input for testing
8. **Reliable Behavior**: Same actions always behave consistently regardless of UI context

## Novel Patterns Demonstrated

- **Start State Pattern**: Superior to optional-based initialization
- **Action Encapsulation**: Actions live in state, not UI code
- **Environment-Based Input Access**: Enables proper closure configuration
- **Buffer Overflow Distinction**: UI actions vs service completion error handling
- **Sendable Closure Patterns**: Explicit @Sendable annotations for isolation safety
