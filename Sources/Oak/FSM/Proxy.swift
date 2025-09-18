import struct Foundation.UUID

/// Asynchronous event channel for mediating communication between a transducer and its environment.
///
/// Provides event sending capabilities and transducer termination control. Must be associated
/// with a transducer by passing it to the transducer's `run` function. Events are buffered
/// internally and processed sequentially by the transducer runtime.
///
/// Automatically terminates the associated transducer when deinitialized to ensure proper
/// resource cleanup.
///
/// - Parameter Event: The type of event transmitted through the proxy.
///
public struct Proxy<Event>: TransducerProxy, Identifiable {

    enum Error: Swift.Error {
        case terminated
        case droppedEvent(String)
        case sendFailed(String)
        case deinitialised
    }

    /// Type alias for the event stream used by the transducer runtime.
    /// 
    /// > Warning: Framework-only API. Do not access directly from user code.
    public typealias Stream = AsyncThrowingStream<Event, Swift.Error>
    typealias Continuation = Stream.Continuation

    /// Asynchronous stream of events consumed by the transducer runtime.
    ///
    /// > Warning: Framework-only API. Do not access directly from user code.
    ///
    /// Events are buffered internally and processed in FIFO order. Stream terminates
    /// gracefully on `finish()` or with error on `cancel(with:)` or proxy deinitialization.
    ///
    /// - Type: `AsyncThrowingStream<Event, Swift.Error>`
    public let stream: Stream
    private let continuation: Continuation

    /// Unique identifier for this proxy instance.
    ///
    /// Generated at initialization and remains stable for the proxy's lifetime.
    /// Used for distinguishing proxies in equality checks and collections.
    public let id: UUID = UUID()

    /// Lightweight interface for sending events to the transducer.
    ///
    /// Designed for use within effects and asynchronous contexts. Conforms to `Sendable`
    /// for safe use across isolation boundaries. Can be created directly from the proxy
    /// or provided by the transducer to effects.
    public struct Input: BufferedTransducerInput {

        internal init(continuation: Continuation) {
            self.continuation = continuation
        }

        let continuation: Continuation

        /// Sends an event to the transducer.
        ///
        /// Safe for use across isolation boundaries due to `Sendable` conformance.
        /// Can be called from effects or external contexts.
        ///
        /// - Parameter event: The event to send.
        /// - Throws: Error if proxy is terminated or buffer is full.
        public func send(_ event: sending Event) throws {
            try Proxy.send(continuation: self.continuation, event: event)
        }
    }

    /// Creates a proxy with specified buffer size and optional initial event.
    ///
    /// Buffer size determines how many events can be queued before dropping oldest events.
    /// When buffer is full, new events cause errors that terminate the transducer.
    ///
    /// - Parameter bufferSize: Maximum buffered events (default: 8).
    /// - Parameter initialEvent: Optional event to enqueue immediately.
    public init(bufferSize: Int = 8, initialEvent: sending Event? = nil) {
        (stream, continuation) = Stream.makeStream(
            bufferingPolicy: .bufferingOldest(bufferSize)
        )
        if let initialEvent {
            do {
                try Self.send(continuation: continuation, event: initialEvent)
            } catch {
                // This can only happen, when the buffer size is less than one,
                // which is a programmer error.
                fatalError(
                    "Could not initialize proxy with initial event: \(error.localizedDescription)")
            }
        }
    }

    /// Creates a proxy with default settings.
    ///
    /// Uses buffer size of 8 events with no initial event. Convenient for use with
    /// `TransducerView` where the proxy parameter is optional.
    public init() {
        self.init(bufferSize: 8, initialEvent: nil)
    }

    /// Sends an event to the transducer.
    ///
    /// Only `Sendable` when `Event` is `Sendable`. For non-`Sendable` contexts,
    /// use the `Input` type instead.
    ///
    /// - Parameter event: The event to send.
    /// - Throws: Error if proxy is terminated or buffer is full.
    public func send(_ event: sending Event) throws {
        try Self.send(continuation: continuation, event: event)
    }

    /// Creates an `Input` instance for sending events to the transducer.
    ///
    /// Returns a lightweight, `Sendable` handle that can be passed between components
    /// for event sending without exposing the full proxy API.
    public var input: Input {
        .init(continuation: self.continuation)
    }

    /// Terminates the proxy ungracefully, causing the transducer to throw an error.
    ///
    /// Should only be used when graceful termination via terminal states is not possible.
    /// The transducer may still process events sent before termination. Idempotent operation.
    ///
    /// - Parameter error: Error to throw from transducer's `run` function (default: `TransducerError.cancelled`).
    public func cancel(with error: Swift.Error? = nil) {
        continuation.finish(throwing: error ?? TransducerError.cancelled)
    }

}

 extension Proxy {

    private static func send(
        continuation: Continuation,
        event: sending Event
    ) throws {
        let result = continuation.yield(event)
        switch result {
        case .enqueued:
            break
        case .dropped(let event):
            throw Error.droppedEvent("Input dropped event: \(event) because event buffer is full")
        case .terminated:
            // TODO: we would like to have `event` here, but the case does not provide it. We can not use the parameter `event` since it is sending.
            throw Error.sendFailed("Input could not enqueue event because it is terminated")
        @unknown default:
            break
        }
    }

    static func descriptionOf(_ event: sending Event) -> String {
        "\(String(describing: event))"
    }
}

extension Proxy: Equatable {
    public static func == (lhs: Proxy<Event>, rhs: Proxy<Event>) -> Bool {
        lhs.id == rhs.id
    }
}

extension Proxy: Sendable where Event: Sendable {}

extension Proxy: TransducerProxyInternal {

    /// Gracefully terminates the event stream.
    /// 
    /// > Warning: Framework-only method. Do not call directly from user code.
    public func finish() {
        continuation.finish()
    }

    /// Validates proxy is not already in use by another transducer.
    /// 
    /// > Warning: Framework-only method. Do not call directly from user code.
    /// 
    /// - Throws: `TransducerError.proxyAlreadyInUse` if proxy is already associated with a running transducer.
    public func checkInUse() throws(TransducerError) {
        // Note: this implementation cannot guarantee,
        // that a proxy can be attempted to be reused
        // when its former transducer has already been
        // terminated. It potentially can also race
        // with simultaneous attempts to use it.
        //
        // However, since the continuation is already
        // terminated, any attempt to do so will fail
        // later when attempting to send events.
        //
        // A better implementation would utilise
        // an atomic boolean value.
        guard continuation.onTermination == nil else {
            throw TransducerError.proxyAlreadyInUse
        }
        continuation.onTermination = { _ in }
    }

}
