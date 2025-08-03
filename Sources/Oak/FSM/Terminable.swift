/// A protocol used to conform transducer _State_ types, defining terminal states in finite state automata.
///
/// ## Overview
///
/// The `Terminable` protocol is a fundamental concept from classical finite state automaton (FSA) theory,
/// implemented here to control transducer execution flow. A state is considered terminal if it cannot
/// transition to any other state, effectively marking the end of the transducer's computation.
///
/// ## Finite State Automaton Context
///
/// In classical FSA theory, terminal (or final/accepting) states represent points where the automaton
/// has successfully completed its computation. The Oak framework uses this concept to:
///
/// - **Control Execution**: Transducers automatically terminate when reaching a terminal state
/// - **Resource Management**: Allows proper cleanup and resource deallocation
/// - **Completion Semantics**: Provides clear success/completion indicators for business logic
///
/// ## Implementation Patterns
///
/// ### Explicit Terminal States
/// ```swift
/// enum ProcessState: Terminable {
///     case idle
///     case processing
///     case completed  // Terminal state
///     case failed     // Terminal state
///
///     var isTerminal: Bool {
///         switch self {
///         case .completed, .failed:
///             return true
///         case .idle, .processing:
///             return false
///         }
///     }
/// }
/// ```
///
/// ### Using NonTerminal for Convenience
/// ```swift
/// // For states that are never terminal
/// enum ActiveState: NonTerminal {
///     case waiting
///     case active
///     case suspended
///     // isTerminal automatically returns false
/// }
/// ```
///
/// ## Transducer Integration
///
/// When a transducer's state becomes terminal:
/// 1. **Execution Stops**: No further state transitions are processed
/// 2. **Completion Callbacks**: Any registered completion handlers are invoked
/// 3. **Resource Cleanup**: The transducer task terminates and releases resources
/// 4. **Final Output**: Any final output values are emitted before termination
///
/// ## Design Considerations
///
/// - **Immutable Semantics**: Terminal status should be determined by the state value itself
/// - **Clear Boundaries**: Terminal states should represent logical completion points
/// - **Error States**: Failed states are typically terminal to prevent invalid transitions
/// - **Success States**: Completed/success states are terminal to indicate successful completion
///
public protocol Terminable {
    var isTerminal: Bool { get }
}

extension Terminable {
}

/// A convenience protocol for states that are never terminal.
///
/// ## Overview
///
/// `NonTerminal` provides a default implementation of `Terminable` that always returns `false`
/// for `isTerminal`. This is useful for state types where no states should ever be terminal,
/// eliminating the need to manually implement `isTerminal` for each case.
///
/// ## Usage
///
/// Use `NonTerminal` when your state machine represents ongoing processes that don't have
/// natural completion points within the state definition itself:
///
/// ```swift
/// enum UIState: NonTerminal {
///     case loading
///     case displaying(content: String)
///     case editing
///     // All states are non-terminal by default
/// }
/// ```
///
/// This is equivalent to manually implementing:
/// ```swift
/// enum UIState: Terminable {
///     case loading
///     case displaying(content: String)
///     case editing
///
///     var isTerminal: Bool { false }
/// }
/// ```
public protocol NonTerminal: Terminable {}

extension NonTerminal {
    public var isTerminal: Bool { false }
}
