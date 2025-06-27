import struct Foundation.UUID

/// A type whose value acts on behalf of a Transducer.
///
/// When a proxy is created, it is not yet associated to a running transducer,
/// i.e. a _transducer identity_. The proxy will be associated to a transducer
/// identity when is passed as a parameter to the transducer's `run` function,
/// which creates a transducer identity and also associates it with the proxy.
///
/// A proxy can be assigned once and only once to one transducer identity.
/// That is, when the transducer reaches a terminal state, the proxy cannot
/// be reused for another transducer. Though, a proxy's life-time can outlive
/// the identity of its transducer.
public protocol TransducerProxy<Event>: Identifiable, Sendable {
    associatedtype Event

    /// A unique identifier which is guaranteed to be unique for every proxy
    /// instance.
    var id: ID { get }

    /// Sends the given event to its transducer.
    ///
    ///`send(_:)` is assumed to run asynchronously with the transducer
    /// which consumes the event. This might require the implementation
    /// to enqueue the event into an internal buffer. The event is then
    /// consumed by the transducer when it will be scheduled to run.
    ///
    /// - Parameter event: The event that is sent to the transducer.
    func send(_ event: sending Event) throws
    
    /// Returns `true` if the proxie's transducer is terminated.
    var isTerminated: Bool { get }
}

protocol Invalidable {
    func invalidate()
}


struct ProxyTerminationError: Swift.Error {}

extension Proxy: Sendable where Event: Sendable {}

extension Proxy.TransducerEvent: Sendable where Event: Sendable {}

// extension Proxy: Sendable where Stream: Sendable {}

/// A Proxy represents a transducer which can be used to send events into
/// it or – if needed – can be used to forcibly terminate the transducer.
///
/// When a proxy is created, it is not yet associated to a running transducer,
/// i.e. a _transducer identity_. The proxy will be associated to a transducer
/// identity when is passed as a parameter to the transducer's `run` function,
/// which creates a transducer identity and also associates it with the proxy.
///
/// A proxy must be assigned once and only once to one transducer identity.
/// When the transducer reaches a terminal state, the proxy must not be
/// reused for another transducer. Though, a proxy's life-time can outlive
/// the identity of its transducer.
///
/// A proxy conforms to `Sendable` when `Event` conforms to `Sendable`.
public struct Proxy<Event>: TransducerProxy {
    typealias Stream = AsyncThrowingStream<TransducerEvent, Swift.Error>
    typealias Continuation = Stream.Continuation
    
    enum Control: Sendable {
        case cancelTask(TaskID)
        case cancelAllTasks
        case dumpTasks
    }
    enum TransducerEvent {
        case event(Event)
        case control(Control)
    }    
    
    let input: Stream
    let continuation: Continuation
    
    /// Initialise a proxy, that can be associated to a transducer by passing it as a parameter
    /// to the `run` function.
    ///
    /// - Parameter eventBufferSize: The number of events, that fit into the internal
    /// event buffer. If the size is not specified, the default is 16.
    public init(eventBufferSize: Int = 16) {
        (input, continuation) = AsyncThrowingStream.makeStream(
            of: TransducerEvent.self,
            throwing: Swift.Error.self,
            bufferingPolicy: .bufferingOldest(eventBufferSize)
        )
    }
    
    /// Initialise a proxy, that can be associated to a transducer by passing it as a parameter
    /// to the `run` function.
    /// 
    /// - Parameter eventBufferSize: The number of events, that fit into the internal
    /// event buffer. If the size is not specified, the default is 16.
    /// - Parameter initialEvents: An array of events which will be send to the input
    /// of the proxy.
    public init(eventBufferSize: Int = 16, initialEvents: sending [Event]) where Event: Sendable {
        (input, continuation) = AsyncThrowingStream.makeStream(
            of: TransducerEvent.self,
            throwing: Swift.Error.self,
            bufferingPolicy: .bufferingOldest(eventBufferSize)
        )
        do {
            try self.send(events: initialEvents)
        } catch {
            fatalError("Failed to enqueue events into the proxy.")
        }
    }

    // TODO: check why Event needs to be Sendable
    /// Initialise a proxy, that can be associated to a transducer by passing it as a parameter
    /// to the `run` function.
    ///
    /// - Parameter eventBufferSize: The number of events, that fit into the internal
    /// event buffer. If the size is not specified, the default is 16.
    /// - Parameter initialEvents: An array of events which will be send to the input
    /// of the proxy.
    public init(eventBufferSize: Int = 16, initialEvents: Event...) where Event: Sendable {
        let events: [Event] = initialEvents
        self.init(eventBufferSize: eventBufferSize, initialEvents: events)
    }
    
    /// A unique identifier which is guaranteed to be unique for every proxy
    /// instance.
    public let id: UUID = UUID()
    
    /// Enques the event and returns immediately.
    /// 
    /// This resumes the transducer loop awaiting the next event and letting it compute
    /// the new state and a new output value.
    /// 
    /// When the event buffer is full or when the transducer is terminated, or when the
    /// current Swift Task is cancelled, an error will be thrown.
    ///
    /// - Parameter event: The event that is sent to the transducer.
    /// 
    /// - Throws: The function `send(_:)` will throw an error when the
    /// underlying event buffer is full or when the transducer is terminated or
    /// when the current Task is cancelled.
    ///
    /// - Important: Events will be enqueued in an internal event buffer before
    /// being processed asynchronously. Sending too many events at once during
    /// one computation cycle of a transducer, for example returning multiple actions
    /// from the `update()` function, may cause the event buffer to overflow.
    public func send(_ event: sending Event) throws {
        if Task.isCancelled {
            throw ProxyInvalidatedError()
        }
        try continuation.send(.event(event))
    }
    
    public func send(events: sending [Event]) throws where Event: Sendable { // TODO: check why Event needs to be Sendable
        if Task.isCancelled {
            throw ProxyInvalidatedError()
        }
        for event in events {
            try continuation.send(.event(event))
        }
    }

    
    /// Forcibly terminates the transducer.
    ///
    /// - Parameter failure: An error that describes the reason for the  termination.
    /// If `nil`, the proxy uses an internal error denoting an irregular error reason.
    ///
    /// - Important: Terminating a transducer via the proxy should be
    /// avoided, especially when called from within an operation of an effect.
    /// Instead, the transition logic should be implemented such, that it
    /// reaches a terminal state when it is deemed finished.
    public func terminate(failure: Swift.Error? = nil) {
        try? cancelAllTasks()
        continuation.finish(throwing: failure ?? ProxyTerminationError())
    }
    
    /// Returns `true` when the transducer is terminated or when the proxy
    /// hasn't been associated to a transducer yet.
    ///
    /// A transducer becomes terminated either by forcibly terminating it,
    /// or when the transducer's state transitioned to a terminal state.
    ///
    /// > Caution: Using this property is prone to race conditions, because
    /// it might have changed shortly after getting the value from the property.
    public var isTerminated: Bool {
        continuation.onTermination == nil
    }
    
    func cancelTask(_ id: TaskID) throws {
        try continuation.send(.control(.cancelTask(id)))
    }

    func cancelAllTasks() throws {
        try continuation.send(.control(.cancelAllTasks))
    }
    
    // #if DEBUG
    public func dumpTasks() throws {
        try continuation.send(.control(.dumpTasks))
    }
    // #endif
}

extension AsyncThrowingStream.Continuation {
    enum ContinuationError: Swift.Error {
        case dropped(String)
        case terminated
        case unknown
    }
    
    func send(_ value: sending Element) throws {
        let result = self.yield(value)
        switch result {
        case .enqueued:
            break
        case .dropped(let element):
            throw ContinuationError.dropped("\(element)")
        case .terminated:
            throw ContinuationError.terminated
        default:
            throw ContinuationError.unknown
        }
    }
}

/// Thrown when the Task where the proxy's `send(_:)` function will be
/// called has been cancelled.
struct ProxyInvalidatedError: Swift.Error {}
