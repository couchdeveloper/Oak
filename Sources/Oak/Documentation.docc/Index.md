# Oak

@Metadata {
   @TechnologyRoot
}

A type-safe finite state machine library for Swift with powerful effect handling and seamless SwiftUI integration.

## Overview

Oak provides a structured approach to application state management through finite state machines (FSMs). Unlike traditional state management patterns that rely on imperative updates and manual synchronization, Oak enforces explicit state transitions with compile-time guarantees about application behavior.

## Why Oak?

Oak transforms application development from reactive debugging to proactive design. By requiring complete state modeling upfront, Oak makes entire categories of bugs impossible while providing a structured approach that aligns naturally with business requirements.

### Key Benefits

#### Fewer Production Bugs
Swift enums for states and events make invalid combinations impossible, while exhaustive transition handling ensures every scenario is covered before your code ships.

#### Faster Debugging
Pure, deterministic transitions mean bugs are perfectly reproducible—no more "works on my machine" or mysterious edge cases that only happen in production.

#### Easier Testing
Side effects are isolated from core logic, so you can unit test state transitions without mocking networks, databases, or timers.

#### Cleaner SwiftUI Code
Native integration eliminates view-model boilerplate while preserving reactive data flow, keeping your UI code focused on presentation.

#### Reliable Concurrency
Actor isolation and structured cancellation prevent race conditions, ensuring your app behaves predictably even under heavy load.

### The Oak Philosophy

Oak's design philosophy centers on making application logic easy to reason about while providing strong guarantees for correct and complete behavior. By modeling states and transitions explicitly, you gain confidence that your application handles every possible scenario—eliminating the guesswork and unexpected edge cases that plague traditional state management approaches.

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
- <doc:table-of-contents>

### Core Concepts

- <doc:Why-Choose-Oak>
- <doc:Finite-State-Machines>
- <doc:Transducers>
- <doc:Effects>

### Patterns & Integration

- <doc:Common-Patterns>
- <doc:SwiftUI-Basics>
- <doc:TransducerView>
- <doc:MVVM-to-Oak>

### Quality & Collaboration

- <doc:Testing-Transducers>
- <doc:AI-Assisted-Development>

### API Reference

- <doc:API-Documentation>
