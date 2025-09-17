import AsyncAlgorithms

import struct Foundation.UUID

/// `SyncSuspendingProxy` is a proxy that sends events into the system using
/// an async non-throwing function.
///
/// When explicitly defining the Proxy type `Oak.SyncSuspendingProxy<Event>`
/// in the `EventTransducer`, we are using a `SyncSuspendingProxy` for sending
/// events into the system. This event delivery mechanism uses an async
/// function to deliver the event that suspends until after the event
/// has been processed. This also includes being suspended until the
/// delivery of an output value (through a Subject) has been completed.
/// Thus, sending an event will never fail, but it may be delayed as
/// needed.
/// The processing speed of the transducer will be dynamically adjusted
/// so that it is synchronised with its event producers and its output
/// consumers through utilising suspension.
public struct SyncSuspendingProxy<Event: Sendable>: TransducerProxy {

    /// Type alias for the event stream used by the transducer runtime.
    /// 
    /// > Warning: Framework-only API. Do not access directly from user code.
    public typealias Stream = AsyncThrowingChannel<Event, Swift.Error>
    
    /// A unique identifier for this proxy instance.
    /// 
    /// - Purpose: Distinguishes this `SyncSuspendingProxy` from other instances,
    ///   enabling features such as equality checks, tracking, and correlation
    ///   across asynchronous workflows.
    /// - Characteristics:
    ///   - Generated at initialization time.
    ///   - Stable for the lifetime of the proxy.
    ///   - Useful for logging, debugging, and associating related resources
    ///     (e.g., auto-cancellation handles) with a specific proxy.
    public let id: UUID = UUID()

    enum Error: Swift.Error {
        case terminated
        case deinitialised
    }

    /// An asynchronous, throwable channel for events emitted by this proxy.
    ///
    /// > Caution: This property is intended for internal use by the Oak framework only.
    /// Client code should not directly access this stream.
    ///
    /// - Type: `AsyncThrowingChannel<Event, Swift.Error>`
    ///
    /// - Purpose: The associated transducer consumes this channel to receive
    ///   events with backpressure control. The channel provides suspension-based
    ///   synchronization between event producers and consumers.
    ///
    /// - Backpressure: Unlike `AsyncThrowingStream`, this channel suspends
    ///   senders until events are fully processed, providing natural flow control.
    ///
    /// - Termination: The channel can be finished gracefully via `finish()` or
    ///   failed with an error via `cancel(with:)`.
    /// 
    /// > Warning: Framework-only API. Do not access directly from user code.
    public let stream: AsyncThrowingChannel<Event, Swift.Error>

    /// A lightweight, send-only handle for feeding events into a `SyncSuspendingProxy`.
    ///
    /// `Input` conforms to `SyncSuspendingTransducerInput` and exposes a single
    /// async, non-throwing `send(_:)` API that delivers events into the proxy’s
    /// internal channel. Sending suspends until the event has been fully processed
    /// by the transducer pipeline, including any downstream subjects that must
    /// complete delivery before resuming. This guarantees backpressure and
    /// synchronization with consumers without surfacing errors to the caller.
    ///
    /// Usage:
    /// - Obtain an instance via `SyncSuspendingProxy.input`.
    /// - Call `await input.send(event)` to enqueue an event.
    /// - Because sending is non-throwing, failure conditions are handled internally
    ///   by the channel/proxy (e.g., cancellation or deinitialization).
    ///
    /// Thread-safety:
    /// - `Input` is safe to use from concurrent contexts. Multiple concurrent
    ///   `send(_:)` calls are permitted; each call will suspend independently
    ///   until its corresponding delivery completes.
    ///
    /// Lifetime and cancellation:
    /// - If the underlying proxy is cancelled or deinitialized, subsequent sends
    ///   may still suspend and resume according to channel semantics, but errors
    ///   are not propagated to the caller. Use the proxy’s `cancel(with:)` or
    ///   `finish()` methods to terminate the stream explicitly when appropriate.
    public struct Input: SyncSuspendingTransducerInput {
        let channel: AsyncThrowingChannel<Event, Swift.Error>

        /// Sends an event into the proxy and suspends until delivery completes.
        ///
        /// This async, non-throwing operation enqueues the provided event into the
        /// proxy’s internal channel and suspends the caller until the event has been
        /// fully processed by the transducer pipeline. Suspension includes the time
        /// required for any downstream subjects or consumers to receive and complete
        /// handling of the event, providing natural backpressure and synchronization.
        ///
        /// - Parameter event: The event to deliver to the transducer.
        /// - Important: Because this method is non-throwing, failures such as
        ///   cancellation or deinitialization are handled internally by the proxy
        ///   and its channel. If you need to explicitly terminate the stream,
        ///   call `cancel(with:)` or `finish()`.
        /// - Concurrency: Safe to call from concurrent contexts. Multiple concurrent
        ///   calls will each suspend independently until their respective deliveries
        ///   complete.
        /// - SeeAlso: `input.send(_:)`, `cancel(with:)`, `finish()`
        public func send(_ event: Event) async {
            await channel.send(event)
        }
    }

    /// Creates a new SyncSuspendingProxy instance with its own internal async channel.
    ///
    /// - Behavior:
    ///   - Initializes an `AsyncThrowingChannel<Event, Swift.Error>` used to deliver events.
    ///   - Generates a unique `id` to identify this proxy instance for logging, tracking, and equality.
    ///   - Establishes the suspension-based backpressure mechanism: calls to `send(_:)` or `input.send(_:)`
    ///     will suspend until each event has been fully processed by the transducer and downstream consumers.
    ///
    /// - Usage:
    ///   - Use the proxy directly via `await send(_:)` or obtain a lightweight, send-only handle via `input`.
    ///   - Manage lifecycle explicitly with `finish()` to close the stream or `cancel(with:)` to fail it.
    ///   - Optionally keep `autoCancellation` alive to ensure the stream is failed automatically if the proxy
    ///     is deinitialized unexpectedly.
    ///
    /// - Thread Safety:
    ///   - The resulting proxy supports concurrent event sends; each send suspends independently until delivery completes.
    ///
    /// - Errors:
    ///   - Sending is non-throwing. Failures (e.g., cancellation, deinitialization) are handled internally by the channel.
    public init() {
        self.stream = .init()
    }

    /// Sends a single event into the proxy and suspends until delivery completes.
    ///
    /// This async, non-throwing operation enqueues the provided event into the
    /// proxy’s internal `AsyncThrowingChannel` and suspends the caller until the
    /// event has been fully processed by the transducer pipeline. Suspension
    /// includes the time required for any downstream subjects or consumers to
    /// receive and complete handling of the event, providing natural backpressure
    /// and synchronization with consumers.
    ///
    /// - Parameter event: The event to deliver to the transducer.
    ///
    /// Discussion:
    /// - Because this method is non-throwing, failures such as cancellation or
    ///   deinitialization are handled internally by the proxy and its channel.
    ///   If you need to explicitly terminate the stream, call `cancel(with:)`
    ///   or `finish()`.
    /// - Safe to call from concurrent contexts. Multiple concurrent calls will
    ///   each suspend independently until their respective deliveries complete.
    ///
    /// See also:
    /// - ``input`` for a lightweight, send-only handle that exposes the same semantics.
    /// - ``cancel(with:)`` to fail the stream with an error.
    /// - ``finish()`` to close the stream gracefully.
    public func send(_ event: Event) async {
        await stream.send(event)
    }

    /// Sends multiple lazily-produced events into the proxy, suspending until each delivery completes.
    ///
    /// This async, non-throwing method accepts a variadic list of closures, each capable of producing
    /// an `Event` when invoked. Events are produced and sent sequentially in the order provided.
    /// For each event, the call suspends until the event has been fully processed by the transducer
    /// pipeline, including any downstream consumers that must complete delivery before resuming.
    /// This provides natural backpressure and synchronization with consumers.
    ///
    /// - Parameter events: A variadic list of zero-argument closures that each return an `Event`.
    ///   Closures are invoked one-by-one, just before their corresponding event is sent, allowing
    ///   for lazy, on-demand event creation and avoiding unnecessary work if earlier events
    ///   trigger cancellation or finishing.
    ///
    /// - Important: Because this method is non-throwing, failure conditions (e.g., cancellation
    ///   or deinitialization) are handled internally by the proxy and its channel. To explicitly
    ///   terminate the stream, use `cancel(with:)` or `finish()`.
    ///
    /// - Concurrency: Safe to call from concurrent contexts. Each send operation within the method
    ///   suspends until its delivery completes; events are still delivered sequentially in the order
    ///   provided.
    ///
    /// - SeeAlso: ``send(_:)`` for sending a single event, ``input`` for a lightweight send-only handle,
    ///   ``cancel(with:)`` to fail the stream, and ``finish()`` to close it gracefully.
    public func send(events: (() -> Event)...) async {
        for event in events {
            await self.send(event())
        }
    }

    /// A lightweight, send-only handle for feeding events into the proxy.
    ///
    /// Accessing `input` provides an `Input` value that exposes a single async,
    /// non-throwing `send(_:)` method to deliver events into the proxy’s internal
    /// channel. Each call to `send(_:)` suspends until the event has been fully
    /// processed by the transducer pipeline, including any downstream subjects,
    /// ensuring natural backpressure and synchronization with consumers.
    ///
    /// Usage:
    /// - Obtain this handle when you need to share event-sending capability
    ///   without exposing the full proxy API (e.g., to avoid accidental
    ///   cancellation/finishing).
    /// - Call `await input.send(event)` to enqueue an event.
    ///
    /// Thread-safety:
    /// - Safe to use from multiple concurrent contexts. Each `send(_:)` call
    ///   suspends independently until its corresponding delivery completes.
    ///
    /// Lifetime and cancellation:
    /// - The handle reflects the lifetime of the underlying proxy. If the proxy
    ///   is cancelled or finished, further sends will be handled according to the
    ///   channel’s semantics without throwing to the caller.
    ///
    /// See also: ``send(_:)``, ``cancel(with:)``
    public var input: Input {
        .init(channel: self.stream)
    }

    /// Cancels the proxy’s event stream by failing it with an error.
    ///
    /// This method terminates the underlying `AsyncThrowingChannel` with a failure,
    /// causing all current and future consumers of the stream to observe the error
    /// and cease receiving further events.
    ///
    /// - Parameter error: An optional error to fail the stream with. If `nil`,
    ///   the stream is failed using `TransducerError.cancelled`.
    ///
    /// Behavior:
    /// - Immediately signals a terminal failure to the channel’s consumers.
    /// - Pending or suspended send operations may resume according to channel
    ///   semantics, but no additional events will be delivered.
    ///
    /// Use cases:
    /// - Explicitly aborting ongoing processing due to external cancellation,
    ///   shutdown, or unrecoverable conditions.
    ///
    /// See also:
    /// - ``finish()`` for a graceful, successful termination without error.
    /// - ``send(_:)`` for delivering events prior to cancellation.
    public func cancel(with error: Swift.Error? = nil) {
        stream.fail(error ?? TransducerError.cancelled)
    }
}

extension SyncSuspendingProxy: TransducerProxyInternal {

    /// Gracefully finishes the proxy's event stream.
    ///
    /// >Caution: This method is intended for internal use by the Oak framework only.
    /// Client code should not call this method directly.
    ///
    /// This function is called by the internal transducer runtime when the state 
    /// of the transducer reaches a terminal state, indicating that no further 
    /// events will be processed.
    ///
    /// - Important: After calling `finish()`, any subsequent attempts to send
    /// events through this proxy (or its `Input`) will fail because the stream
    /// is terminated.
    ///
    /// - Note: Use `finish()` for normal, graceful shutdowns. If you need to
    /// forcefully terminate processing with an error (e.g. due to an external
    /// cancellation or failure), use `cancel(with:)` instead.
    /// See also:
    /// - ``cancel(with:)`` to terminate the stream with an error.
    public func finish() {
        stream.finish()
    }
}