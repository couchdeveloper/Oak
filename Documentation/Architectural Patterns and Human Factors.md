# Architectural Patterns and Human Factors: Why Bugs Creep In

## Introduction: The Root of Most Bugs

Software is built by people, and people are not perfect. Many software defects are not born from a lack of technical skill, but from simple, predictable human factors. A key concept is **cognitive load**: the amount of information a developer must actively hold in their mind to write correct code. When an architecture forces a high cognitive load, the likelihood of human error—and thus, bugs—increases dramatically.

This document explores common human factors that lead to bugs and analyzes how different architectural paradigms either exacerbate or mitigate these risks.

---

## Part 1: Common Human Factors That Cause Bugs

We can identify several recurring human factors that are common sources of defects in software development.

### 1. The Burden of Memory (Forgetfulness)

-   **The Problem**: Complex systems often require developers to remember to perform critical but routine actions, such as resource cleanup or state management. A prime example is manually managing the lifecycle of an asynchronous task. The developer must *remember* to cancel a running task before starting a new one and *remember* to cancel all tasks when a screen is dismissed.
-   **The Human Factor**: Forgetting is human. Under pressure or when focused on a feature's "happy path," it is easy to overlook this essential cleanup logic. This isn't a sign of a bad developer; it's a sign of a system that places a high memory burden on them.

### 2. The Risk of Repetition (Habituation & Copy-Paste Errors)

-   **The Problem**: Many architectures lead to repetitive boilerplate code. For instance, the logic for managing an asynchronous task's lifecycle might be repeated in every `ViewModel` or `Interactor` that fetches data.
-   **The Human Factor**: When code is highly repetitive, developers can become habituated and prone to copy-paste errors. They might paste the boilerplate but forget to adapt it correctly for the new context. Worse, a bug in the original boilerplate gets propagated to dozens of places, making it difficult to fix comprehensively.

### 3. The Complexity of State (Cognitive Overload)

-   **The Problem**: In many systems, the developer has to mentally juggle numerous transient states. "Is a network request running? Is there a previous request? What happens if the user taps the button again right now? What if the data comes back after the user has navigated away?"
-   **The Human Factor**: Reasoning about all possible states and transitions simultaneously is mentally taxing. It's easy to miss a potential race condition or an edge case where the UI could end up in an inconsistent state (e.g., showing a loading spinner and an error message at the same time).

### 4. The Illusion of Separation (Low Locality of Behaviour)

-   **The Problem**: "Separation of concerns" is a core principle of software design, but when taken to an extreme, it can lead to low *Locality of Behaviour* (LoB). This means the code required to understand a single feature or user interaction is scattered across many different files, classes, and modules.
-   **The Human Factor**: While the code is neatly separated by its *technical role* (View, Logic, Routing), it's not organized by *feature*. To understand what happens when a user taps a button, a developer might have to trace the call stack through a `View`, a `ViewModel`, a `Router`, an `Interactor`, and multiple `Services`. This constant context-switching increases cognitive load and makes it difficult to form a mental model of the feature's complete behaviour. Principles like Inversion of Control and Dependency Injection, while powerful, can exacerbate this by creating complex runtime object graphs that are hard to reason about from static code alone.

---

## Part 2: How Traditional Architectures Address Human Factors

Traditional imperative architectures—such as **MVVM, VIPER, MVC, and MVP**—provide structure but often rely heavily on developer discipline, which makes them susceptible to the human factors listed above.

-   **Exacerbating Forgetfulness**: These patterns place the full burden of task lifecycle management on the developer. The `ViewModel` or `Interactor` is responsible for manually creating, storing, and, crucially, *remembering* to cancel tasks. This makes them highly vulnerable to memory-related errors.

-   **Encouraging Repetition**: They naturally lead to the repetition of task management boilerplate across many different components, increasing the risk of copy-paste errors and making the codebase harder to maintain.

-   **Increasing Cognitive Load**: By mixing business logic with the complex, stateful logic of concurrency management, these patterns increase the cognitive load on the developer, forcing them to reason about race conditions and edge cases in every component that handles asynchronous work.

-   **Fragmenting Behaviour (Low LoB)**: By design, these architectures enforce a strict separation of technical concerns. A single feature is deliberately split across a `View`, `Presenter`/`ViewModel`, `Interactor`, and `Router`. This leads to very low Locality of Behaviour, forcing developers to navigate a web of dependencies and callbacks to understand a single workflow.

In essence, these architectures require the developer to be a perfect, disciplined machine. They provide the tools but leave the responsibility for avoiding common pitfalls entirely in the developer's hands.

---

## Part 3: How Declarative Architectures Mitigate Human Factors

Declarative, state-machine-based architectures—such as **Oak** and **The Composable Architecture (TCA)**—are designed to reduce cognitive load by shifting responsibility from the developer to the framework.

-   **Offloading Memory to the Framework**: These architectures directly address the forgetfulness factor. The developer no longer needs to *remember* to cancel tasks. The framework does it automatically based on clear, declarative rules (e.g., a new effect supersedes an old one, or a state becomes terminal). This removes an entire class of bugs by design. The developer simply declares their *intent* (an `Effect`), and the framework handles the complex, error-prone implementation.

-   **Promoting Abstraction over Repetition**: The logic for task lifecycle management is implemented *once* within the framework's runtime. It is not repeated in the business logic of each feature. This follows the "Don't Repeat Yourself" (DRY) principle, creating a single source of truth that is more robust and easier to maintain.

-   **Simplifying State Management**: The core business logic is often contained in a pure function (like Oak's `update` or TCA's `reducer`). The developer only needs to think about the current `State` and the incoming `Event` to produce a new `State`. They don't have to simultaneously manage the state of the asynchronous task itself. This dramatically lowers the cognitive load, making the logic easier to test and reason about.

-   **Improving Locality of Behaviour (High LoB)**: These architectures tend to organize code by *feature* or *component*. The `State`, `Event`s (or `Action`s), and the `update` logic (`Reducer`) for a single screen or component are often co-located in a single file or a small number of related files. This high Locality of Behaviour means a developer can see all the possible states, all the possible events, and all the logic for that feature in one place, making it much easier to reason about.

## Conclusion

The most robust software systems are not those that demand perfection from their developers, but those that acknowledge human fallibility and are designed to prevent common errors by default.

By reducing cognitive load—offloading memory, eliminating repetition, simplifying state, and improving the locality of behaviour—declarative architectures like Oak provide a safety net that catches common human errors before they can become bugs. This leads to code that is not only more reliable and easier to test but also simpler and more enjoyable to write.
