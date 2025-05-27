
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
///
/// A proxy is _sendable_, means, it can be moved across arbitrary concurrent
/// contexts.
public protocol TransducerProxy<Event>: Sendable, Identifiable {
    associatedtype Event
    associatedtype ID: Hashable
    
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

import struct Foundation.UUID

struct ProxyTerminationError: Swift.Error {}

/// A Proxy represents a transducer which can be used to send events into
/// it or – if needed – can be used to forcibly terminate the transducer.
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
///
/// A proxy is _sendable_, means, it can be moved across arbitrary concurrent
/// contexts.
public struct Proxy<Event>: TransducerProxy, Sendable where Event: Sendable {
    typealias Stream = AsyncThrowingStream<TransducerEvent, Swift.Error>
    typealias Continuation = Stream.Continuation
    
    enum Control: Sendable {
        case cancelTask(TaskID)
        case cancelAllTasks
        case dumpTasks
    }
    enum TransducerEvent: Sendable {
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
        continuation.onTermination = { _ in }
    }
    
    /// Initialise a proxy, that can be associated to a transducer by passing it as a parameter
    /// to the `run` function.
    /// 
    /// - Parameter eventBufferSize: The number of events, that fit into the internal
    /// event buffer. If the size is not specified, the default is 16.
    /// - Parameter initialEvents: An array of events which will be send to the input
    /// of the proxy.
    public init(eventBufferSize: Int = 16, initialEvents: [Event]) {
        (input, continuation) = AsyncThrowingStream.makeStream(
            of: TransducerEvent.self,
            throwing: Swift.Error.self,
            bufferingPolicy: .bufferingOldest(eventBufferSize)
        )
        continuation.onTermination = { _ in }
        do {
            try initialEvents.forEach { try self.send($0) }
        } catch {
            fatalError("Failed to enqueue events into the proxy.")
        }
    }

    /// Initialise a proxy, that can be associated to a transducer by passing it as a parameter
    /// to the `run` function.
    ///
    /// - Parameter eventBufferSize: The number of events, that fit into the internal
    /// event buffer. If the size is not specified, the default is 16.
    /// - Parameter initialEvents: An array of events which will be send to the input
    /// of the proxy.
    public init(eventBufferSize: Int = 16, initialEvents: Event...) {
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
    /// When the event buffer is full or when the transducer is terminated, an
    /// exception will be thrown.
    ///
    /// - Parameter event: The event that is sent to the transducer.
    ///
    /// - Important: Events will be processed asynchronously. Sending too many
    /// events in a short duration may cause the event buffer to overflow.
    public func send(_ event: sending Event) throws {
        try continuation.send(.event(event))
    }
    
    /// Forcibly terminates the transducer.
    ///
    /// - Parameter failure: An error that describes the reason for the  termination.
    /// If `nil`, the proxy uses an internal error denoting an irregular error reason.
    ///
    /// - Important: Terminating the transducer via the proxy
    /// should be avoided. Instead, implement the transition logic such,
    /// that it reaches a terminal state. Once the transducer's state reaches
    /// a terminal state, it will be terminated orderly.
    public func terminate(failure: Swift.Error? = nil) {
        try? cancelAllTasks()
        continuation.finish(throwing: failure ?? ProxyTerminationError())
    }
    
    /// Returns `true` when the transducer is terminated.
    ///
    /// A transducer becomes terminated either by forcibly terminating it,
    /// or when the transducer's state transitioned to a terminal state.
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

extension AsyncThrowingStream.Continuation where Element: Sendable {
    enum ContinuationError: Swift.Error {
        case dropped(Element)
        case terminated
        case unknown
    }
    
    func send(_ value: Element) throws {
        let result = self.yield(value)
        switch result {
        case .enqueued:
            break
        case .dropped(let element):
            throw ContinuationError.dropped(element)
        case .terminated:
            throw ContinuationError.terminated
        default:
            throw ContinuationError.unknown
        }
    }
}

public struct ProxyInvalidatedError: Swift.Error {}

struct ActionProxy<Event: Sendable>: TransducerProxy {
    private let proxy: Proxy<Event>
    
    init(proxy: Proxy<Event>) {
        self.proxy = proxy
    }
    
    var id: UUID {
        return proxy.id
    }
    
    func send(_ event: sending Event) throws {
        try self.proxy.send(event)
    }
    
    var isTerminated: Bool {
        self.proxy.isTerminated
    }
}


final class EffectProxy<Event: Sendable>: Oak.TransducerProxy, Invalidable, @unchecked Sendable {
    
    private var proxy: Proxy<Event>?
    
    init(proxy: Proxy<Event>) {
        self.proxy = proxy
    }
    
    var id: UUID {
        guard let proxy else {
            fatalError("proxy is invalidated")
        }
        return proxy.id
    }
    
    func send(_ event: sending Event) throws {
        guard let proxy else {
            throw ProxyInvalidatedError()
        }
        try proxy.send(event)
    }
    
    /// Returns `true` if the transducer is terminated or if self is invalidated.
    var isTerminated: Bool {
        proxy?.isTerminated ?? true
    }
    
    func cancelTask<ID>(_ id: ID) throws where ID: Hashable, ID: Sendable {
        try proxy?.cancelTask(TaskID(id))
    }
    
    func cancelAllTasks() throws {
        try proxy?.cancelAllTasks()
    }
    
    func invalidate() {
        self.proxy = nil
    }
}
