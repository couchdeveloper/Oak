# ``Oak``

A type-safe finite state machine library for Swift with powerful effect handling and seamless SwiftUI integration.

## Overview

Oak provides a structured approach to application state management through finite state machines (FSMs). Unlike traditional state management patterns that rely on imperative updates and manual synchronization, Oak enforces explicit state transitions with compile-time guarantees about application behavior.

### The Problem with "Edge Cases"

Traditional application development often suffers from what the industry calls "edge cases" - unexpected behaviors that surface when software encounters inputs or conditions that weren't explicitly considered during design. These are typically treated as inevitable bugs that require reactive debugging.

However, most "edge cases" aren't truly edge cases at all. They're evidence of **incomplete specifications** and **implicit assumptions** that weren't made explicit in the code. For example:

- A form accepts "numbers 1-100" but crashes on input "0" or "abc"
- An authenticated user's session expires, but the app assumes authentication is permanent
- A network request fails, but the UI assumes it always succeeds

Oak fundamentally eliminates this category of problems by requiring **complete state modeling** upfront. When you define a finite state machine, you must explicitly handle every possible state and every possible event. The compiler prevents you from deploying incomplete specifications.

### From Reactive Debugging to Proactive Design

Oak transforms the development process from:
- ❌ "We'll handle edge cases when they appear"
- ❌ "Some bugs are inevitable in complex systems"  
- ❌ "Boolean flags can represent any combination"

To:
- ✅ "Every possible scenario must be explicitly modeled"
- ✅ "Impossible states are literally impossible to represent"
- ✅ "The compiler verifies complete coverage"

This shift from **reactive debugging culture** to **proactive design culture** doesn't eliminate human error, but it makes entire categories of errors impossible and forces thorough analysis where it matters most.

### AI-Assisted Development

Oak's structured approach creates an ideal environment for AI-assisted coding. The finite state machine pattern provides clear, mechanical rules that AI can follow systematically while humans focus on creative problem-solving and domain expertise.

**Where AI Excels with Oak:**
- **State Space Expansion**: Given requirements like "user authentication with session timeout," AI can suggest comprehensive state enums covering all scenarios
- **Exhaustive Refactoring**: When adding new states or events, AI systematically updates all affected transitions without missing cases
- **Pattern Completion**: AI recognizes incomplete `switch` statements and suggests missing state/event combinations
- **Consistency Checking**: AI verifies that state transitions follow logical rules and identifies unreachable states or impossible combinations

**The Perfect Division of Labor:**
- **Humans provide**: Domain knowledge, business rules, acceptance criteria, and high-level architectural decisions
- **AI handles**: Mechanical pattern matching, exhaustive case analysis, systematic refactoring, and type-safe code generation

This collaboration is particularly powerful because FSMs separate concerns cleanly - timing and performance belong in Effects (not state transitions), domain logic is expressed as business rules (not implementation details), and the compiler verifies correctness regardless of who wrote the code.

**Real-World Impact:**
Rather than spending hours manually updating dozens of transition cases when requirements change, developers can focus on the conceptual design while AI handles the systematic implementation. This dramatically reduces the cognitive load of FSM development and eliminates the tedious refactoring work that traditionally made state machines feel cumbersome.

### Key Benefits

**Type Safety**: Oak leverages Swift's type system to prevent invalid state transitions at compile time. Every possible state and event combination must be explicitly handled, eliminating undefined behavior.

**Predictable State Changes**: State transitions follow mathematical rules defined in pure functions. This deterministic approach makes application behavior predictable and reproducible.

**Effect Isolation**: Side effects are separated from state logic through Oak's Effect system. This separation improves testability and makes complex async operations manageable.

**SwiftUI Native**: Oak integrates directly with SwiftUI's reactive system through `TransducerView` and environment injection, requiring no external dependencies or view model layers.

**Concurrent Safety**: Built on Swift's structured concurrency model with proper actor isolation and `Sendable` compliance throughout.

### When to Use Oak

Oak excels in scenarios requiring reliable state management:

- Multi-step workflows with clear phases (onboarding, checkout, data loading)
- Complex forms with validation and error states
- Features requiring precise state coordination (authentication flows, real-time updates)
- Applications where state bugs have serious consequences
- Teams wanting to reduce state-related debugging time

Oak may be unnecessary for simple views with minimal state requirements or applications with very basic user interactions.

## Topics

### Tutorials

- <doc:table-of-contents>

### FSM Core

- ``Transducer``
- ``EffectTransducer`` 
- ``Effect``
- ``BaseTransducer``

### SwiftUI Integration

- ``TransducerView``
- ``ObservableTransducer``

### Advanced Features

- ``TransducerActor``
- ``TransducerProxy``
- ``Subject``
- ``Callback``

### Utilities

- ``Terminable``
- ``NonTerminal``
- ``TransducerError``