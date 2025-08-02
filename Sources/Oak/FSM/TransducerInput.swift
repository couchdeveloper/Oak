/// Represents the input interface for a transducer in a finite state machine (FSM).
///
/// ## Overview
///
/// The `SyncSuspendingTransducerInput` protocol is a fundamental concept from classical finite state automaton 
/// (FSA) theory, representing the input alphabet and event delivery mechanism. In FSA theory, inputs 
/// drive state transitions, making this protocol crucial for transducer operation.
///
/// ## Key Features
///
/// ### Execution Semantics: "Synchronous and Suspending"
/// `SyncSuspendingTransducerInput` provides **synchronous computation semantics**:
/// - **Suspends** until the transducer's computation completes
/// - **Waits** for all action effects to finish
/// - **Waits** for any output values to be sent
/// - **Guarantees** the event has been fully processed before returning
///
/// This provides strong consistency guarantees but may impact performance in high-throughput scenarios.
///
/// ### Sendable Value Semantics
/// Unlike traditional input mechanisms, `SyncSuspendingTransducerInput` is a `Sendable` value type that can be:
/// - **Copied freely**: Multiple references can exist without ownership concerns
/// - **Used anywhere**: Safe to pass across actor boundaries and concurrent contexts
/// - **Shared safely**: No synchronization required for access
///
/// ### Composable System Architecture
/// The copyable, sendable nature makes it extremely handy for building and composing systems of 
/// transducers where:
/// - One transducer's output connects to another's input
/// - Event distribution to multiple transducers
/// - Complex transducer networks and pipelines
///
/// ## Usage Patterns
///
/// ### Direct Event Sending
/// ```swift
/// // Simple event delivery
/// await input.send(.userAction)
/// await input.send(.dataReceived(data))
/// ```
///
/// ### Transducer Composition
/// ```swift
/// // Connect transducer outputs to inputs
/// struct ComposedSystem {
///     let processorInput: some SyncSuspendingTransducerInput<ProcessEvent>
///     let displayInput: some SyncSuspendingTransducerInput<DisplayEvent>
///     
///     func handleProcessorOutput(_ output: ProcessResult) async {
///         // Transform and forward to display transducer
///         await displayInput.send(.showResult(output))
///     }
/// }
/// ```
///
/// ### Multi-cast Event Distribution
/// ```swift
/// // Share input across multiple consumers
/// let sharedInput = transducer.input
/// let inputCopy1 = sharedInput  // Safe to copy
/// let inputCopy2 = sharedInput  // Each copy is independent
/// 
/// // Use from different contexts
/// Task { await inputCopy1.send(.event1) }
/// Task { await inputCopy2.send(.event2) }
/// ```
///
/// ## Finite State Automaton Context
///
/// In classical FSA theory, the input represents:
/// - **Input Alphabet (Σ)**: The set of possible events/symbols
/// - **Transition Function**: Events trigger state transitions δ(state, input) → state
/// - **Event Sequence**: The ordered sequence of inputs that drive computation
///
/// The Oak framework extends this concept with modern concurrency and composition capabilities
/// while maintaining the theoretical foundation.
///
/// ## Error Handling
///
/// Events may fail to be delivered in scenarios such as:
/// - Transducer has reached a terminal state
/// - Event buffer overflow (if buffering is used)
/// - Invalid event for current state (implementation-dependent)
///
public protocol SyncSuspendingTransducerInput<Event>: Sendable {
    associatedtype Event
    
    /// Sends an event to the transducer.
    /// 
    /// - Parameter event: The event to be sent.
    /// - Throws: An error if the event cannot be delivered, 
    /// for example, the transducer is already terminated, or 
    /// the event buffer is full.
    func send(_ event: Event) async
}


/// Represents the buffered input interface for a transducer in a finite state machine (FSM).
///
/// ## Overview
///
/// `BufferedTransducerInput` provides a buffered, non-suspending input mechanism that contrasts with 
/// `SyncSuspendingTransducerInput`'s synchronous computation semantics.
///
/// ### Execution Semantics: "Asynchronous and Non-Suspending"
/// `BufferedTransducerInput` provides **asynchronous computation semantics**:
/// - **Enqueues** events into an internal buffer
/// - **Returns immediately** without waiting for computation
/// - **Computation happens asynchronously** in the background
/// - **Higher throughput** due to buffering and immediate return
///
/// This provides better performance for high-throughput scenarios but with weaker consistency guarantees.
///
/// ## Comparison with SyncSuspendingTransducerInput
///
/// | Aspect | `BufferedTransducerInput` | `SyncSuspendingTransducerInput` |
/// |--------|---------------------------|---------------------------------|
/// | **Execution** | Asynchronous & Non-Suspending | Synchronous & Suspending |
/// | **Buffering** | Internal event buffer | Direct computation |
/// | **Return Timing** | Immediate (after enqueue) | After full computation |
/// | **Throughput** | Higher (buffered) | Lower (synchronous) |
/// | **Consistency** | Eventual | Strong |
/// | **Use Cases** | High-volume events | Guaranteed completion |
///
/// ## Naming Clarification
///
/// The new naming scheme is self-documenting:
/// - `BufferedTransducerInput` → **Buffered, asynchronous computation** (events queued, immediate return)
/// - `SyncSuspendingTransducerInput` → **Synchronous computation with suspension** (waits for completion)
///
/// ## Usage
///
/// Prefer `BufferedTransducerInput` when:
/// - **High throughput** is required
/// - **Fire-and-forget** semantics are acceptable
/// - **Buffering** events is beneficial
/// - Working in **synchronous contexts** (no `async`/`await`)
///
/// ```swift
/// // Events are buffered and processed asynchronously
/// do {
///     try input.send(.highVolumeEvent1)
///     try input.send(.highVolumeEvent2)
///     try input.send(.highVolumeEvent3)
///     // All events enqueued immediately, processing happens in background
/// } catch {
///     // Handle buffer overflow or termination
/// }
/// ```
///
/// Prefer `SyncSuspendingTransducerInput` when:
/// - **Guaranteed completion** before proceeding is required
/// - **Strong consistency** is needed
/// - **Coordination** with computation results is necessary
///
/// ```swift
/// // Wait for complete processing before continuing
/// await syncInput.send(.criticalEvent)
/// // Event is fully processed, effects completed, outputs sent
/// ```
///
public protocol BufferedTransducerInput<Event>: Sendable {
    associatedtype Event
    
    /// Sends an event to the transducer.
    ///
    /// - Parameter event: The event to be sent.
    /// - Throws: An error if the event cannot be delivered,
    /// for example, the transducer is already terminated, or
    /// the event buffer is full.
    func send(_ event: sending Event) throws
}
