# Oak Framework

A type-safe finite state machine library for Swift with powerful effect handling and seamless SwiftUI integration.

## Overview

Oak provides a structured approach to application state management through finite state machines (FSMs). Unlike traditional state management patterns that rely on imperative updates and manual synchronization, Oak enforces explicit state transitions with compile-time guarantees about application behavior.

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

### Getting Started

- <doc:Installation>
- <doc:First-State-Machine>
- <doc:SwiftUI-Basics>

### Migration

- <doc:MVVM-to-Oak>
- <doc:Common-Patterns>

### Core Concepts

- <doc:Finite-State-Machines>
- <doc:Transducers>
- <doc:State-Modeling>
- <doc:Effects>

### SwiftUI Integration

- <doc:TransducerView>
- <doc:Environment-Injection>
- <doc:Hierarchical-Architecture>

### Examples

- <doc:Counter-Example>
- <doc:Data-Loading>
- <doc:Form-Validation>
- <doc:Navigation-Flow>

### Testing

- <doc:Testing-Transducers>
- <doc:Testing-Effects>
- <doc:Integration-Testing>

### Advanced Usage

- <doc:Performance>
- <doc:Composition>
- <doc:Debugging>