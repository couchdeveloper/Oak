# ``Oak``

A type-safe finite state machine library for Swift with powerful effect handling and seamless SwiftUI integration.

## Overview

Oak provides a structured approach to application state management through finite state machines (FSMs). Unlike traditional state management patterns that rely on imperative updates and manual synchronization, Oak enforces explicit state transitions with compile-time guarantees about application behavior.

## Why Oak?

Oak transforms application development from reactive debugging to proactive design. By requiring complete state modeling upfront, Oak makes entire categories of bugs impossible while providing a structured approach that aligns naturally with business requirements.

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

### AI Collaboration

Oak's structured approach creates an ideal environment for AI-assisted coding. The finite state machine pattern provides clear, mechanical rules that AI can follow systematically while humans focus on creative problem-solving and domain expertise.

This collaboration dramatically reduces the cognitive load of FSM development and eliminates the tedious refactoring work that traditionally made state machines feel cumbersome.

## Getting Started

Begin your Oak journey with our interactive tutorial: <doc:table-of-contents>

For a comprehensive exploration of Oak's benefits for teams and businesses, see <doc:Why-Choose-Oak>.

Learn about AI-assisted development patterns in <doc:AI-Assisted-Development>.

## Topics

### Core Transducer Protocols

- ``Transducer``
- ``EffectTransducer``
- ``BaseTransducer``

### Effect System

- ``Effect``
- ``Subject``
- ``Callback``

### SwiftUI Integration

- ``TransducerView``
- ``ObservableTransducer``

### Advanced Features

- ``TransducerActor``
- ``TransducerProxy``

### State Management Utilities

- ``Terminable``
- ``NonTerminal``
- ``TransducerError``