import AsyncAlgorithms

import struct Foundation.UUID

/// Suspension-based proxy that sends events using async non-throwing functions
/// with backpressure control.
///
/// Uses suspension-based event delivery that waits until events are fully
/// processed, including completion of output delivery through subjects. Provides
/// natural flow control by synchronizing event producers with the transducer's
/// processing speed.
///
/// Events are sent via `AsyncThrowingChannel` which suspends callers until
/// processing completes, eliminating buffer overflow issues through backpressure
/// management.
public struct SyncSuspendingProxy<Event: Sendable>: TransducerProxy {

    /// Type alias for the event stream used by the transducer runtime.
    /// 
    /// > Warning: Framework-only API. Do not access directly from user code.
    public typealias Stream = AsyncThrowingChannel<Event, Swift.Error>
    
    /// Unique identifier for this proxy instance.
    /// 
    /// Generated at initialization and stable for the proxy's lifetime.
    /// Used for distinguishing proxies in equality checks and resource tracking.
    public let id: UUID = UUID()

    enum Error: Swift.Error {
        case terminated
        case deinitialised
    }

    /// Asynchronous channel for events with backpressure control.
    ///
    /// > Warning: Framework-only API. Do not access directly from user code.
    ///
    /// Provides suspension-based synchronization between event producers and
    /// consumers. Unlike `AsyncThrowingStream`, suspends senders until events
    /// are fully processed.
    ///
    /// - Type: `AsyncThrowingChannel<Event, Swift.Error>`
    public let stream: AsyncThrowingChannel<Event, Swift.Error>

    /// Lightweight, send-only handle for feeding events into the proxy.
    ///
    /// Provides async, non-throwing `send(_:)` method that suspends until event
    /// delivery completes. Safe for concurrent use from multiple contexts.
    /// Errors are handled internally by the channel rather than surfaced to
    /// callers.
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
        ///   cancellation or deinitialization are handled internally by the
        ///   proxy and its channel. If you need to explicitly terminate the
        ///   stream, call `cancel(with:)` or `finish()`.
        /// - Concurrency: Safe to call from concurrent contexts. Multiple
        ///   concurrent calls will each suspend independently until their
        ///   respective deliveries complete.
        /// - SeeAlso: `input.send(_:)`, `cancel(with:)`, `finish()`
        public func send(_ event: Event) async {
            await channel.send(event)
        }
    }

    /// Creates a new SyncSuspendingProxy with backpressure-controlled event
    /// delivery.
    ///
    /// Initializes an `AsyncThrowingChannel` for suspension-based synchronization
    /// between event producers and consumers. Calls to `send(_:)` suspend until
    /// events are fully processed by the transducer and downstream consumers.
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

    /// Sends multiple lazily-produced events sequentially.
    ///
    /// Accepts variadic closures that produce events on-demand. Events are sent
    /// sequentially with suspension until each delivery completes, providing
    /// backpressure control. Lazy evaluation avoids unnecessary work if
    /// cancellation occurs.
    ///
    /// - Parameter events: Closures that return events when invoked.
    public func send(events: (() -> Event)...) async {
        for event in events {
            await self.send(event())
        }
    }

    /// Lightweight, send-only handle for event delivery.
    ///
    /// Provides async, non-throwing `send(_:)` method with suspension-based backpressure.
    /// Safe for concurrent use. Useful for sharing event-sending capability without
    /// exposing full proxy API (cancellation/finishing).
    public var input: Input {
        .init(channel: self.stream)
    }

    /// Cancels the proxy's event stream with an error.
    ///
    /// Terminates the underlying channel with failure, causing consumers to observe
    /// the error and cease receiving events. Pending send operations may resume
    /// according to channel semantics but no additional events are delivered.
    ///
    /// - Parameter error: Error to fail stream with (default: `TransducerError.cancelled`).
    public func cancel(with error: Swift.Error? = nil) {
        stream.fail(error ?? TransducerError.cancelled)
    }
}

extension SyncSuspendingProxy: TransducerProxyInternal {

    /// Gracefully finishes the proxy's event stream.
    ///
    /// > Warning: Framework-only method. Do not call directly from user code.
    ///
    /// Called by transducer runtime when reaching terminal state. After calling,
    /// subsequent event sending attempts will fail.
    public func finish() {
        stream.finish()
    }
}