import struct Foundation.UUID

/// `Proxy` is an asynchronous event channel that mediates communication between a
/// transducer and its environment.
///
/// # Overview
/// A proxy provides a mechanism for sending events into a state machine and
/// a means to terminate a transducer in an ungraceful way, if needed. It is also
/// required to establish the event processing pipeline for a transducer.
/// Thus a proxy _must_ be associated with a transducer by passing it as a
/// parameter to the transducer's `run` function:
/// ```swift
/// let proxy = MyTransducer.Proxy()
/// try await MyTransducer.run(
///     initialState: state,
///     proxy: proxy,
///     env: environment
/// )
/// ```
///
/// When the proxy, associated to the transducer will be deinitialised, and its
/// transducer is still runnning, it also forcibly terminates the transducer, so that
/// it is guaranteed that the transducer is stoped and all used resources will be
/// deallocated.
///
/// > Note: All events sent to the proxy are first enqueued in an internal buffer
/// > before being processed sequentially by the transducer. This approach does not
/// > support back pressure. Thus, sending events may fail if the event buffer
/// > reaches its capacity limit.
///
/// ## Features
/// - Integrates with the transducer runtime for event flow management.
/// - Safe for concurrent use by multiple event producers.
/// - Supports sending events and control signals.
/// 
/// ## Detailed Description
///
/// The proxy provides a means to send events into a transducer. Internally, the
/// proxy creates an `AsyncThrowingStream` to buffer events. The transducer
/// runtime will consume these events using an asynchronous loop and process
/// them in the order they were received. Thus, a proxy must be associated with
/// a transducer by passing it as parameter to the `run` function, so that the
/// transducer can process the events.
/// 
/// A proxy instance can only be used by a single transducer. Once the transducer
/// reaches a terminal state, the proxy will no longer accept events and will
/// terminate the stream.
///
///
/// ## Usage Examples
/// Events can be sent from outside of the system directly using the proxy:
/// ```swift
/// try proxy.send(.userTappedButton)
/// try proxy.send(events: { .started }, { .configured })
/// ```
///
/// From within an effect, use the provided `Input` to send events in response to
/// asynchronous operations:
/// ```swift
/// let effect = T.Effect(
///     id: ID("fetchBooks"),
///     operation: { @MainActor env, input in
///         let result = await env.fetchAllBooks()
///         try input.send(.fetchBooksResponse(result))
///     }
/// )
/// ```
///
/// ## Input Interface
/// The nested `Input` type provides a lightweight interface for sending events
/// into the system:
/// - Can be freely passed between components.
/// - Works from any source and any isolation context.
/// - Enables effects and external systems to inject events.
/// - Maintains isolation between event producers and proxy implementation.
///
/// - Parameter Event: The type of event transmitted through the proxy.
/// 
public struct Proxy<Event>: TransducerProxy, Identifiable {
    
    enum Error: Swift.Error {
        case terminated
        case droppedEvent(String)
        case sendFailed(String)
    }
    
    public typealias Stream = AsyncThrowingStream<Event, Swift.Error>
    typealias Continuation = Stream.Continuation
        
    public let stream: Stream
    private let continuation: Continuation
    
    public let id: UUID = UUID()

    /// The Input type provides a way to send events into the transducer.
    /// 
    /// It is designed to be used within effects or other asynchronous contexts
    /// where you need to send events back to the transducer.
    public struct Input: TransducerInput {
        
        internal init(continuation: Continuation) {
            self.continuation = continuation
        }
        
        let continuation: Continuation
        
        /// Sends the specified event to the transducer.
        /// 
        /// An `Input` instance will be provided by the transducer to its effects,
        /// allowing them to send events back to the transducer. But an instance of
        /// `Input` can also be created directly from the proxy, allowing you to send
        /// events from outside the transducer's context.
        /// 
        /// The Input value conforms to `Sendable` allowing it to be used across
        /// different threads or isolation contexts, ensuring that events can be sent
        /// safely from any asynchronous context.
        /// 
        /// - Parameter event: The event to send.
        /// 
        /// - Throws: An error if the event could not be sent, for example when the proxy is 
        /// terminated or the event buffer is full.
        public func send(_ event: sending Event) throws {
            try Proxy.send(continuation: self.continuation, event: event)
        }
    }

    /// Initializes a new `Proxy` instance with a specified event buffer size.
    /// 
    /// The buffer size determines how many events can be buffered before
    /// new events are dropped. If the buffer is full, sending new events
    /// will result in an error, which terminates the transducer with an error.
    ///
    /// - Parameter bufferSize: The maximum number of events that can be buffered
    /// before dropping the oldest ones. The default value is 8.
    /// 
    /// > Note: Being able to buffer eight events is a reasonable default for most use cases,
    ///   but you can adjust this value based on your application's requirements.
    ///   A larger buffer size may increase memory usage, while a smaller buffer size may 
    ///   increase the risk of an event being dropped, which terminates the transducer with 
    ///   an error.
    public init(bufferSize: Int = 8) {
        (stream, continuation) = Stream.makeStream(
            bufferingPolicy: .bufferingOldest(bufferSize)
        )
    }
        
    /// Sends the specified event to the transducer.
    /// 
    /// In contrast to the `Input` type, `Proxy` is only Sendable when type 
    /// `Event` is Sendable. This means that if you need to send events from 
    /// a non-Sendable context, you must use the `Input` type instead.
    /// 
    /// - Parameter event: The event to send.
    /// 
    /// - Throws: An error if the event could not be sent, for example when the proxy is 
    /// terminated or the event buffer is full.
    public func send(_ event: sending Event) throws {
        try Self.send(continuation: continuation, event: event)
    }

    // public func send(events: (() -> sending Event)...) throws {
    //     for event in events {
    //         try self.send(event())
    //     }
    // }
    
    /// Creates an `Input` instance that can be used to send events to the transducer
    /// and returns it.
    public var input: Input {
        .init(continuation: self.continuation)
    }

    /// Terminates the proxy, preventing any further events from being sent and causing
    /// the `run` function to return with a `CancellationError`.
    ///
    /// This method should only be called when the transducer needs to be shut
    /// down in an ungraceful way. Usually, the transducer will terminate itself
    /// gracefully by processing all events and reaching a terminal state.
    public func cancel() {
        continuation.finish(throwing: TransducerError.cancelled)
    }
    
    public func finish(error: Swift.Error? = nil) {
        continuation.finish(throwing: error)
    }
    
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
    
    public func checkInUse() throws(TransducerError) {
        // Note: this implementation cannot guarantee,
        // that a proxy can be attempted to be reused
        // when its former transducer has already been
        // terminated. It ptotentially can also race
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
