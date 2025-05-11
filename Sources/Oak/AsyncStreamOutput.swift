public struct AsyncStreamOutput<Value: Sendable>: Subject, Sendable {
    
    enum Error: Swift.Error {
        case terminated
        case dropped
        case unknown
    }
    
    public typealias Stream = AsyncThrowingStream<Value, Swift.Error>
    
    public let stream: Stream
    
    let continuation: Stream.Continuation
        
    public init() {
        (stream, continuation) = Stream.makeStream()
    }
    
    public func send(_ value: Value) throws -> Void {
        let result = continuation.yield(value)
        switch result {
        case .enqueued:
            break
        case .dropped:
            throw Error.dropped
        case .terminated:
            throw Error.terminated
        default:
            throw Error.unknown
        }
    }
}

