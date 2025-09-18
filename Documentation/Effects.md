# Effects in Oak Framework

## Overview

Effects are Oak's mechanism for managing side effects in finite state machines. They provide a controlled, type-safe way to interact with the external world while maintaining the purity of state transitions. This document explores the deep technical concepts, architectural design decisions, and practical implementation patterns of Oak's Effect system.

## What is a Side Effect?

In functional programming and finite state machines, a **side effect** is any interaction with the external world or any operation that goes beyond pure computation. Examples include:

- Network requests and HTTP calls
- File system operations
- Database queries
- Timer operations and delays
- User interface updates
- Logging and analytics
- Push notifications
- Hardware interactions

Oak's FSM model follows the principle of **pure state transitions**: the `update` function must be deterministic and free of side effects. All external interactions must be encapsulated as Effects, which are returned from `update` and executed by the Oak runtime.

## The Role of Effects in Oak's Architecture

### Separation of Concerns

Oak enforces a clear architectural boundary:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Pure Logic    │    │   Effect Layer   │    │ External World  │
│                 │    │                  │    │                 │
│  State Machine  │───▶│     Effects      │───▶│   Environment   │
│   Transitions   │    │   (Side Effects) │    │   Services      │
│                 │    │                  │    │   Hardware      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

**Pure Logic Layer:** State transitions, business rules, and decision making happen here. The `update` function is deterministic, testable, and predictable.

**Effect Layer:** Bridge between pure logic and the external world. Effects encapsulate all side effects with proper error handling, cancellation, and lifecycle management.

**External World:** Network services, databases, file systems, hardware, and other external dependencies.

## Understanding Environment (`Env`)

### What is Environment?

The **Environment** (`Env`) is Oak's dependency injection mechanism for Effects. It provides a clean, testable way to access external services and configuration without violating the separation of concerns.

```swift
// Production Environment
@MainActor
struct AppEnvironment: Sendable {
    let networkService: NetworkService
    let database: Database
    let logger: Logger
    let configuration: AppConfiguration
}

// Test Environment
struct TestEnvironment: Sendable {
    let networkService: MockNetworkService
    let database: InMemoryDatabase
    let logger: NoOpLogger
    let configuration: TestConfiguration
}
```

### What Environment Enables

Environment is optional - Effects can work with empty environments (e.g., `struct Env {}`). However, when you need external dependencies, Environment provides:

1. **Dependency Injection:** Clean access to services without global state
2. **Testability:** Easy to swap implementations for testing
3. **Type Safety:** Compile-time verification of available dependencies
4. **Actor Isolation:** Safe access to actor-isolated services
5. **Configuration Management:** Centralized access to settings and feature flags

### Environment Design Patterns

#### Service-Based Environment
```swift
struct Environment: Sendable {
    let api: APIService
    let storage: StorageService
    let analytics: AnalyticsService
}
```

#### Protocol-Based Environment
```swift
struct Environment: Sendable {
    let networkProvider: any NetworkProvider & Sendable
    let storageProvider: any StorageProvider & Sendable
}
```

#### Actor-Isolated Environment
```swift
@MainActor
class UIEnvironment: ObservableObject {
    let imageCache: ImageCache
    let navigationController: NavigationController
}
```

## Effect Implementation Details

### Action Effects - Structured Concurrency

Action Effects represent **synchronous side effects** that execute during the state transition cycle using Swift's structured concurrency model.

#### Technical Characteristics

**Execution Model:**
- Execute on the caller's actor (global actor or system actor)
- Use structured concurrency (`async`/`await`)
- Events are processed immediately and synchronously
- Suspend Input event processing until completion

**Isolation Guarantees:**
- Maintain actor isolation throughout execution
- Safe access to actor-isolated environments
- No risk of concurrent state mutations

**Performance Profile:**
- Minimal overhead (no Task creation)
- Very fast execution for CPU-bound work
- Optimal for immediate computations

#### When to Use Action Effects

1. **Environment Data Import:** Bringing external data into the state machine
2. **Configuration Setup:** Initializing services or setting up context
3. **Immediate Computations:** CPU-bound work that needs immediate results
4. **State-Dependent Logic:** Operations that require current state guarantees

#### Implementation Patterns

**Global Actor Isolation:**
```swift
// Environment isolated to @MainActor
@MainActor
struct UIEnvironment {
    let viewController: UIViewController
    let animator: UIViewPropertyAnimator
}

// Action Effect with matching isolation
static func updateUIEffect() -> Effect {
    Effect(action: { @MainActor env in
        // Safe to access UIKit components
        env.viewController.title = "Updated"
        env.animator.startAnimation()
        return .uiUpdated
    })
}
```

**System Actor Isolation:**
```swift
// For environments that aren't actor-isolated
static func processDataEffect() -> Effect {
    Effect(isolatedAction: { env, isolated in
        // Execute on system actor
        let result = env.processor.process(data)
        return .dataProcessed(result)
    })
}
```

### Operation Effects - Unstructured Tasks

Operation Effects represent **asynchronous side effects** that execute as unstructured Tasks managed by the Oak runtime.

#### Technical Characteristics

**Execution Model:**
- Execute as independent Swift Tasks
- Use unstructured concurrency
- Events sent asynchronously via Input channel
- Concurrent execution with other operations

**Task Management:**
- Automatic lifecycle management
- Explicit cancellation support via identifiers
- Graceful handling of CancellationError
- Cleanup on transducer termination

**Isolation Considerations:**
- Can cross actor boundaries safely
- Support both global actor and system actor execution
- Proper Task isolation ensures thread safety

#### When to Use Operation Effects

1. **Network Operations:** HTTP requests, WebSocket connections
2. **File I/O:** Reading, writing, and processing files
3. **Database Operations:** Queries, updates, migrations
4. **Timer Operations:** Delays, periodic tasks, timeouts
5. **Long-Running Work:** Background processing, computations
6. **Cancellable Operations:** Work that needs explicit cancellation

#### Implementation Patterns

**Network Request Pattern:**
```swift
static func loadUserEffect(id: String) -> Effect {
    Effect(id: "loadUser", isolatedOperation: { env, input, isolated in
        do {
            let user = try await env.api.loadUser(id: id)
            try input.send(.userLoaded(user))
        } catch {
            try input.send(.userLoadFailed(error))
        }
    })
}
```

**Cancellable Timer Pattern:**
```swift
static func startTimeoutEffect(duration: TimeInterval) -> Effect {
    Effect(
        id: "timeout",
        isolatedOperation: { env, input, isolated in
            try await Task.sleep(for: .seconds(duration))
            try input.send(.timeout)
        },
        after: .seconds(duration)
    )
}

static func cancelTimeoutEffect() -> Effect {
    .cancelTask("timeout")
}
```

**Background Processing Pattern:**
```swift
static func processLargeDataEffect(data: LargeDataSet) -> Effect {
    Effect(id: "backgroundProcess", operation: { @MainActor env, input in
        // Process on background queue
        let results = await withTaskGroup(of: ProcessedChunk.self) { group in
            for chunk in data.chunks {
                group.addTask {
                    await env.processor.process(chunk)
                }
            }
            
            var results: [ProcessedChunk] = []
            for await result in group {
                results.append(result)
                // Send progress updates
                try? input.send(.progressUpdate(results.count, data.chunks.count))
            }
            return results
        }
        
        try input.send(.processingComplete(results))
    })
}
```

## Actor Isolation and Sendable Conformance

### Understanding Swift Concurrency in Effects

Oak's Effect system is built on Swift 6's strict concurrency model, ensuring data race safety across actor boundaries.

#### Sendable Requirements

**Environment Sendable:**
```swift
// Correct: Environment conforms to Sendable
struct Environment: Sendable {
    let service: any ServiceProtocol & Sendable
    let configuration: Configuration // Configuration must also be Sendable
}

// Incorrect: Non-Sendable environment
class Environment { // Classes are not automatically Sendable
    let service: ServiceProtocol // Protocol without Sendable requirement
}
```

**Event Sendable:**
```swift
// Events must be Sendable for safe transmission
enum Event: Sendable {
    case dataLoaded(Data) // Data is Sendable
    case userInfo(UserInfo) // UserInfo must conform to Sendable
}

struct UserInfo: Sendable {
    let id: String
    let name: String
    // All properties must be Sendable
}
```

#### Actor Isolation Patterns

**Global Actor Isolation:**
```swift
@MainActor
struct UIEnvironment {
    let viewModel: ViewModel // Isolated to @MainActor
}

// Effect runs on @MainActor
Effect(action: { @MainActor env in
    env.viewModel.updateState() // Safe access
    return .stateUpdated
})
```

**System Actor Isolation:**
```swift
// Effect runs on system actor (where transducer runs)
Effect(isolatedAction: { env, isolated in
    // `isolated` parameter provides actor isolation
    // Safe to access across actor boundaries
    return .operationComplete
})
```

**Cross-Actor Communication:**
```swift
// From background actor to MainActor
Effect(id: "crossActor", isolatedOperation: { env, input, isolated in
    // Process on background
    let result = await heavyComputation()
    
    // Send to MainActor safely
    await MainActor.run {
        env.uiUpdater.display(result)
    }
    
    try input.send(.displayUpdated)
})
```

### Safe Patterns for Actor Boundaries

#### Pattern 1: Match Environment Isolation
```swift
@MainActor
struct UIEnvironment { ... }

// Match the environment's actor
Effect(action: { @MainActor env in
    // Safe access to @MainActor environment
})
```

#### Pattern 2: Use System Actor for Universal Access
```swift
Effect(isolatedAction: { env, isolated in
    // Runs on system actor, safe for any environment
})
```

#### Pattern 3: Explicit Actor Switching
```swift
Effect(isolatedOperation: { env, input, isolated in
    // Background work
    let data = await backgroundProcessing()
    
    // Switch to main actor for UI updates
    await MainActor.run {
        env.ui.update(data)
    }
    
    try input.send(.updated)
})
```

## Error Handling in Effects

### Error Categories

#### System Errors (Transducer Termination)
```swift
Effect(isolatedOperation: { env, input, isolated in
    do {
        let result = try await env.service.criticalOperation()
        try input.send(.success(result))
    } catch {
        // Non-cancellation errors terminate the transducer
        throw error // This will terminate the entire state machine
    }
})
```

#### Business Logic Errors (Event-Based)
```swift
Effect(isolatedOperation: { env, input, isolated in
    do {
        let result = try await env.service.businessOperation()
        try input.send(.success(result))
    } catch {
        // Handle as business logic, don't terminate transducer
        try input.send(.failure(error))
    }
})
```

#### Cancellation Handling
```swift
Effect(isolatedOperation: { env, input, isolated in
    do {
        let result = try await env.service.longRunningOperation()
        try input.send(.completed(result))
    } catch is CancellationError {
        // Cancellation is handled gracefully by Oak runtime
        // No need to send events or handle explicitly
        return
    } catch {
        // Other errors are business logic
        try input.send(.failed(error))
    }
})
```

## Testing Strategies

### Environment Mocking

```swift
// Test environment with mocked services
struct TestEnvironment: Sendable {
    let api: MockAPIService
    let storage: MockStorage
    
    static func success() -> TestEnvironment {
        TestEnvironment(
            api: MockAPIService(responses: [.success]),
            storage: MockStorage()
        )
    }
    
    static func failure() -> TestEnvironment {
        TestEnvironment(
            api: MockAPIService(responses: [.failure(.networkError)]),
            storage: MockStorage()
        )
    }
}
```

### Effect Testing

```swift
func testLoadUserEffect() async throws {
    let env = TestEnvironment.success()
    let input = TestInput<Event>()
    
    let effect = MyTransducer.loadUserEffect(id: "123")
    
    try await effect.invoke(
        env: env,
        input: input,
        context: TestContext(),
        systemActor: #isolation
    )
    
    XCTAssertEqual(input.sentEvents, [.userLoaded(expectedUser)])
}
```

## Performance Considerations

### Action Effect Performance
- **Overhead:** Minimal (no Task creation)
- **Latency:** Immediate execution
- **Best for:** CPU-bound work < 1ms
- **Avoid for:** Network I/O, file operations

### Operation Effect Performance
- **Overhead:** Task creation cost (~microseconds)
- **Latency:** Asynchronous execution
- **Best for:** I/O operations, long-running work
- **Cancellation:** Explicit cleanup possible

### Memory Management
- **Avoid Capturing:** Don't capture values in effect closures
- **Use Environment:** Access dependencies via `env` parameter
- **Task Lifecycle:** Operations are automatically cleaned up
- **Actor Retention:** Be careful with actor-isolated environment retention

## Advanced Patterns

### Effect Composition

```swift
// Sequential composition
static func setupEffect() -> Effect {
    .combine(
        initializeServicesEffect(),
        loadConfigurationEffect(),
        startBackgroundTasksEffect()
    )
}

// Conditional composition
static func conditionalEffect(feature: FeatureFlag) -> Effect {
    feature.enabled ? 
        enabledFeatureEffect() : 
        disabledFeatureEffect()
}
```

### State-Dependent Effects

```swift
static func contextualEffect(for state: State) -> Effect {
    switch state {
    case .idle:
        return startMonitoringEffect()
    case .processing(let data):
        return processDataEffect(data)
    case .error:
        return retryEffect()
    }
}
```

### Resource Management

```swift
static func managedResourceEffect() -> Effect {
    Effect(id: "resource", isolatedOperation: { env, input, isolated in
        let resource = await env.resourceManager.acquire()
        defer { Task { await env.resourceManager.release(resource) } }
        
        let result = try await resource.performOperation()
        try input.send(.operationComplete(result))
    })
}
```

## Best Practices

### 1. Naming Conventions
- Use descriptive names: `loadUserDataEffect()` not `effect1()`
- Include context: `retryNetworkRequestEffect()` vs `retryEffect()`
- Indicate async nature: `backgroundSyncEffect()` for long operations

### 2. Environment Design
- Keep environments focused and cohesive
- Use protocols for testability
- Consider actor isolation requirements
- Minimize dependencies

### 3. Error Handling Strategy
- Reserve termination for truly fatal errors
- Use events for recoverable failures
- Handle cancellation gracefully
- Provide meaningful error context

### 4. Performance Optimization
- Choose appropriate effect type (Action vs Operation)
- Avoid capturing values in closures
- Use cancellation for resource cleanup
- Monitor Task creation overhead

### 5. Testing Approach
- Create focused test environments
- Test both success and failure paths
- Verify cancellation behavior
- Use dependency injection effectively

## Integration with Oak Framework

Effects are integral to Oak's FSM architecture, enabling:

- **Pure State Machines:** Clean separation of logic and side effects
- **Testable Architecture:** Mockable environments and predictable behavior
- **Swift Concurrency:** First-class support for modern Swift patterns
- **Type Safety:** Compile-time verification of effect interactions
- **Performance:** Optimized execution models for different use cases

The Effect system transforms potentially complex, error-prone side effect management into a structured, type-safe, and highly testable component of your application architecture.