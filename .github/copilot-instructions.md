# Oak Framework - AI Coding Assistant Instructions

This document provides Oak-specific patterns and examples.

> Repository policy: For high-level, tool-agnostic guidance shared across assistants, see `AI_GUIDELINES.md`. Treat that file as the canonical repo policy; Also refer to [BasicSystemPrompt](BasicSystemPrompt.md) for platform rules, quality and best practices.

## Purpose & Scope (For Agents)
- Optimize for concise, correct changes; avoid large refactors unless requested.
- Follow Oak’s FSM model: pure `update`, effects in `Effect`, Swift concurrency.
- Respect terminal states and `Sendable` boundaries; do not add global state.
- Keep edits surgical and in-repo; don’t invent APIs or move files unnecessarily.

## Quick Rules For Agents
- Safety: No side effects in `update`. Effects may send events; action effects process synchronously.
- Concurrency: Honor isolation; use `@Sendable` where values cross boundaries.
- State: Prefer enums; implement `isTerminal` precisely. Don’t ignore terminal transitions.
- Testing: Use existing XCTest targets. Avoid real timers/networking in tests.
- Docs: Update docs when changing effect/terminal behavior. Link to `AI_GUIDELINES.md`.

## Workflows At A Glance
- Run tests: `swift test` (targets: `OakTests`, `OakBenchmarks`).
- Format: `./Scripts/formatCode.sh`.
- Docs: `./Scripts/previewDocs.sh` or `./Scripts/generateDocs.sh`.
- SwiftUI usage: Prefer `TransducerView` or `ObservableTransducer` over `ObservableObject`.

## Project Overview

Oak is a Swift finite state machine (FSM) library built on structured concurrency, designed for type-safe, reactive application architecture with SwiftUI integration. It emphasizes pure functional state transitions separated from side effects.

## Core Architecture Concepts

### Transducer Definition Pattern
```swift
// Simple Transducer - no effects, direct output
enum SimpleCounter: Transducer {
    // REQUIRED: State definition
    enum State: NonTerminal {
        case start
        case idle(count: Int)
    }
    
    // REQUIRED: Event definition
    enum Event {
        case start
        case increment, decrement
    }
    
    // REQUIRED: Output typealias when producing output
    typealias Output = Int
    
    // REQUIRED: update function returning output directly
    static func update(_ state: inout State, event: Event) -> Output {
        switch (state, event) {
        case (.start, .start):
            state = .idle(count: 0)
            return 0
        case (.idle(let count), .increment):
            state = .idle(count: count + 1)
            return count + 1
        case (.idle(let count), .decrement):
            state = .idle(count: max(0, count - 1))
            return max(0, count - 1)
        default:
            // When reaching in the `default` case , it may indicate 
            // a violation of the assumptions about the system. You 
            // may want to log or handle this case.

            // Handle unexpected combinations
            return 0
        }
    }
    
    // RECOMMENDED: Initial state definition
    static var initialState: State { .start }
    
    // REQUIRED for Moore automata: Initial output function
    static func initialOutput(initialState: State) -> Output? {
        switch initialState {
        case .start: return nil
        case .idle(let count): return count
        }
    }
}

// EffectTransducer - with async effects
enum MyTransducer: EffectTransducer {
    // REQUIRED: State definition
    enum State: Terminable {
        case start
        case idle, processing, finished
        var isTerminal: Bool { self == .finished }
    }
    
    // REQUIRED: Event definition  
    enum Event {
        case start
        case process, complete
    }
    
    // REQUIRED: Output typealias when producing output
    typealias Output = String
    
    // REQUIRED: update function returning effects
    static func update(_ state: inout State, event: Event) -> Effect? {
        switch (state, event) {
        case (.start, .start):
            state = .idle
            return nil // Ready to handle events
        case (.idle, .process):
            state = .processing
            return someAsyncEffect()
        // ... other transitions
        default:
            return nil
        }
    }
    
    // RECOMMENDED: Initial state definition
    static var initialState: State { .start }
    
    // REQUIRED for Moore automata: Initial output function
    // Only handles valid initial states (.start in this case)
    static func initialOutput(initialState: State) -> Output? {
        switch initialState {
        case .start: return nil
        // Only include cases for states that can be initial states
        }
    }
}
```

### Transducer Types
- **`Transducer`**: Basic FSM with pure state transitions, returns `Output` directly
- **`EffectTransducer`**: Advanced FSM that can trigger side effects, returns `Effect?` or `(Effect?, Output)`
- **`BaseTransducer`**: Type container for composition without implementation requirements

### State Management Philosophy
```swift
// Prefer SUM types (enums) over PRODUCT types (structs) for State
enum State: Terminable {
    case idle(value: Int)
    case loading
    case finished(result: String)
    
    var isTerminal: Bool { 
        if case .finished = self { return true }
        return false
    }
}

// When context is known, choose appropriately:
// - Use NonTerminal for states that never terminate
// - Use Terminable with explicit isTerminal logic for sequence recognition patterns

// Pure update functions - no closures over external variables
// No effects (Output may be Void):
static func update(_ state: inout State, event: Event) -> Output

// With effects and output:
static func update(_ state: inout State, event: Event) -> (Self.Effect?, Output)

// With effects, no output (Output is Void):
static func update(_ state: inout State, event: Event) -> Self.Effect?
```

### SwiftUI Integration Patterns
- **`TransducerView`**: Primary integration - manages lifecycle, uses `@State` binding from parent
- **`ObservableTransducer`**: For ViewModels or standalone state management
- **Environment injection**: Use `@Entry` for dependencies in `EnvironmentValues`

```swift
// TransducerView uses binding - parent can observe and react to state changes
struct ParentView: View {
    @State private var transducerState = MyTransducer.initialState
    
    var body: some View {
        VStack {
            // Parent can observe state and take actions
            if transducerState.isProcessing {
                Text("Working...")
            }
            
            TransducerView(
                of: MyTransducer.self,
                initialState: $transducerState,  // Binding allows parent observation
                env: env
            ) { state, input in
                // UI that reacts to state, sends events via input
            }
        }
    }
}
```

### Hierarchical FSM Architecture
Parent views can act as mediators or hubs, observing outputs from child TransducerViews and routing them as events to other FSMs. This enables building connected hierarchies of state machines through SwiftUI's composition model, where parents coordinate communication between multiple child transducers and handle cross-cutting concerns like navigation and data flow.

### Blended SwiftUI and FSM State Management
Oak FSMs can integrate seamlessly with SwiftUI's native state management patterns. For example, in NavigationSplitView architectures, SwiftUI can handle UI-specific state (like selection) while FSMs manage business logic. The SideBar and Detail views react to SwiftUI selection state changes and send corresponding events to their respective FSMs, creating a clean separation between UI state and business logic.

## Development Workflows

### Testing
```bash
# Run all tests
swift test

# Run specific test target
swift test --filter OakTests
swift test --filter OakBenchmarks
```

### Documentation
```bash
# Generate and preview docs locally
./Scripts/previewDocs.sh

# Generate static docs for deployment
./Scripts/generateDocs.sh
```

### Code Quality
```bash
# Format code (requires swift-format)
./Scripts/formatCode.sh
```

## Coding Conventions

### File Organization
- **FSM Core**: `Sources/Oak/FSM/` - base protocols and runtime
- **SwiftUI Integration**: `Sources/Oak/SwiftUI/` - view components and adapters
- **Examples**: `Examples/Sources/Examples/` - practical usage patterns
- **Tests**: Separate targets for unit tests (`OakTests`) and benchmarks (`OakBenchmarks`)

### Effect Patterns
```swift
// Operation effects for async work
static func networkEffect() -> Effect {
    Effect(id: "fetch") { env, input in
        let data = try await env.service.fetch()
        try input.send(.dataReceived(data))
    }
}

// Action effects for immediate responses
static func navigationEffect(destination: Route) -> Effect {
    .event(.navigate(destination))
}
// Note: Action events are processed before any events sent via Input
```

### State Design
- Use enums for distinct states: `.idle`, `.loading`, `.error(Error)`
- Prefer structs for data-heavy states with computed properties
- Always handle terminal states explicitly in `isTerminal`

### Environment Injection
```swift
// Define environment for dependencies (only required for EffectTransducers)
// Env must conform to Sendable for safe concurrent access across isolation domains
struct Env: Sendable {
    var service: @Sendable () async throws -> Data
    var logger: @Sendable (String) -> Void
}

// Register in SwiftUI environment
extension EnvironmentValues {
    @Entry var myTransducerEnv: MyTransducer.Env = .production
}
```

## Common Patterns

### Request-Permission Flow
Events named `intentWill*` request permission vs `intentDid*` for notifications after completion.

### Hierarchical State Machines
Parent transducers coordinate child transducers through output->input connections:
```swift
// Parent receives child output, forwards as events
let childCallback = Callback<Child.Output> { output in
    try? parentInput.send(.childResult(output))
}
```

### Modal State Management
Use state-driven modals where transducer state determines UI presentation:
```swift
enum State {
    case start
    case idle(Data)
    case modal(sheet: SheetItem, content: Data)
}
```

## Dependencies

- **Swift 6.2+**: Leverages strict concurrency and actor isolation
- **AsyncAlgorithms**: For advanced async sequence operations
- **SwiftUI**: Primary UI integration target (iOS 15+, macOS 12+)
- **Swift-DocC**: Documentation generation

## Anti-Patterns to Avoid

- Don't perform side effects directly in `update()` functions
- In the `update()` functions - always handle all cases explicitly
- In the `update()` functions - do not use a `default` case to 
  handle expected and valid transitions - it may mask unhandled 
  states/events. `default` should only be used for truly unexpected 
  cases and invalid assumptions - i.e. a state/event combination that
  should never occur in normal operation. Always log this incident
  or issue a fatal error.

## General Do's and Don'ts
- State should always have a `start` state, indicating an "uninitialized" condition
- Event should have a `start` event.
- Avoid complex nested state structures - prefer flat, normalized designs
- Don't mix UI state with business logic state
- Prefer `TransducerView` over "ViewModels"
- If a Transducer has a user-defined output, always declare this type in the Transducer enum.

## Documentation and Communication

### Pull Request Descriptions
When composing PR descriptions for Oak framework changes:

- **Structure**: Use clear sections (Key Improvements, Breaking Changes) with descriptive headers
- **Focus on impact**: Explain what problems are solved and benefits gained - the details are in the code
- **Be concise**: Avoid implementation specifics, line counts, or file statistics
- **Highlight breaking changes**: Clearly call out any API changes that could affect users
- **Group related changes**: Organize commits into logical themes (error handling, terminal state management, etc.)
- **Skip obvious details**: Don't mention that tests pass or include redundant technical notes
- **Target audience**: Write for developers who will use the framework, not just maintainers

## Key Files for Reference

- **`Sources/Oak/FSM/Transducer.swift`**: Core protocol definitions
- **`Sources/Oak/SwiftUI/TransducerView.swift`**: Primary SwiftUI integration
- **`Examples/Sources/Examples/Counters/`**: Basic and effect-based examples
- **`Sources/Oak/FSM/Effect.swift`**: Effect creation and execution patterns