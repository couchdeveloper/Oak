import os
// Possibly use: https://github.com/swhitty/swift-mutex/blob/main/Sources/Mutex.swift

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
final class Expectation: Sendable {
    
    enum Error: Swift.Error {
        case deinitalized
        case timeout
        case alreadyAwaited
    }
    
    typealias Continuation = CheckedContinuation<Void, any Swift.Error>

    enum State {
        case start(minFulfillCount: Int)
        case partiallyFulfilled(
            minFulfillCount: Int,
            fulfillCount: Int
        )
        case pending(
            Continuation,
            minFulfillCount: Int,
            fulfillCount: Int,
            timeoutTask: Task<Void,Swift.Error>?
        )
        case fulfilled(minFulfillCount: Int, fulfillCount: Int)
        case rejected(any Swift.Error)
    }
        
    let lock: OSAllocatedUnfairLock<State>

    init(minFulfillCount: Int = 1) {
        lock = .init(initialState: .start(minFulfillCount: minFulfillCount))
    }
    
    var isFulfilled: Bool {
        return lock.withLock { state in
            if case .fulfilled = state {
                return true
            } else {
                return false
            }
        }
    }
    
    func await(
        nanoseconds: UInt64
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: Continuation) in
            self.lock.withLock { state in
                switch state {
                case .start(let minFulfillCount):
                    let timeoutTask = Task { [weak self] in
                        try await Task.sleep(nanoseconds: nanoseconds)
                        self?.fail(with: Error.timeout)
                    }
                    state = .pending(
                        continuation,
                        minFulfillCount: minFulfillCount,
                        fulfillCount: 0,
                        timeoutTask: timeoutTask
                    )

                case .partiallyFulfilled(let minFulfillCount, let fulfillCount):
                    assert(fulfillCount < minFulfillCount)
                    let timeoutTask = Task { [weak self] in
                        try await Task.sleep(nanoseconds: nanoseconds)
                        self?.fail(with: Error.timeout)
                    }
                    state = .pending(
                        continuation,
                        minFulfillCount: minFulfillCount,
                        fulfillCount: fulfillCount,
                        timeoutTask: timeoutTask
                    )

                case .rejected(let error):
                    continuation.resume(throwing: error)
                
                case .fulfilled(let minFulfillCount, let fulfillCount):
                    assert(fulfillCount >= minFulfillCount)
                    let newFulfillCount = fulfillCount - minFulfillCount
                    if newFulfillCount >= minFulfillCount {
                        state = .fulfilled(
                            minFulfillCount: minFulfillCount,
                            fulfillCount: newFulfillCount
                        )
                    } else {
                        state = .partiallyFulfilled(
                            minFulfillCount: minFulfillCount,
                            fulfillCount: newFulfillCount
                        )
                    }
                    continuation.resume()
                
                case .pending:
                    continuation.resume(throwing: Error.alreadyAwaited)
                }
            }
        }
    }
    
    func await<C: Clock>(
        timeout duration: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = ContinuousClock(),
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: Continuation) in
            self.lock.withLock { state in
                switch state {
                case .start(let minFulfillCount):
                    let timeoutTask = Task { [weak self] in
                        try await Task.sleep(
                            for: duration,
                            tolerance: tolerance,
                            clock: clock
                        )
                        self?.fail(with: Error.timeout)
                    }
                    state = .pending(
                        continuation,
                        minFulfillCount: minFulfillCount,
                        fulfillCount: 0,
                        timeoutTask: timeoutTask
                    )

                case .partiallyFulfilled(let minFulfillCount, let fulfillCount):
                    assert(fulfillCount < minFulfillCount)
                    let timeoutTask = Task { [weak self] in
                        try await Task.sleep(
                            for: duration,
                            tolerance: tolerance,
                            clock: clock
                        )
                        self?.fail(with: Error.timeout)
                    }
                    state = .pending(
                        continuation,
                        minFulfillCount: minFulfillCount,
                        fulfillCount: fulfillCount,
                        timeoutTask: timeoutTask
                    )

                case .rejected(let error):
                    continuation.resume(throwing: error)
                
                case .fulfilled(let minFulfillCount, let fulfillCount):
                    assert(fulfillCount >= minFulfillCount)
                    let newFulfillCount = fulfillCount - minFulfillCount
                    if newFulfillCount >= minFulfillCount {
                        state = .fulfilled(
                            minFulfillCount: minFulfillCount,
                            fulfillCount: newFulfillCount
                        )
                    } else {
                        state = .partiallyFulfilled(
                            minFulfillCount: minFulfillCount,
                            fulfillCount: newFulfillCount
                        )
                    }
                    continuation.resume()
                
                case .pending:
                    continuation.resume(throwing: Error.alreadyAwaited)
                }
            }
        }
    }
        
    func await() async throws {
        try await withCheckedThrowingContinuation { (continuation: Continuation) in
            self.lock.withLock { state in
                switch state {
                case .start(let minFulfillCount):
                    state = .pending(
                        continuation,
                        minFulfillCount: minFulfillCount,
                        fulfillCount: 0,
                        timeoutTask: nil
                    )

                case .partiallyFulfilled(let minFulfillCount, let fulfillCount):
                    assert(fulfillCount < minFulfillCount)
                    state = .pending(
                        continuation,
                        minFulfillCount: minFulfillCount,
                        fulfillCount: fulfillCount,
                        timeoutTask: nil
                    )
                
                case .rejected(let error):
                    continuation.resume(throwing: error)
                
                case .fulfilled(let minFulfillCount, let fulfillCount):
                    assert(fulfillCount >= minFulfillCount)
                    let newFulfillCount = fulfillCount - minFulfillCount // consume minFulfillCount
                    if newFulfillCount >= minFulfillCount {
                        state = .fulfilled(
                            minFulfillCount: minFulfillCount,
                            fulfillCount: newFulfillCount
                        )
                    } else {
                        state = .partiallyFulfilled(
                            minFulfillCount: minFulfillCount,
                            fulfillCount: newFulfillCount
                        )
                    }
                    continuation.resume()
                
                case .pending:
                    continuation.resume(throwing: Error.alreadyAwaited)
                }
            }
        }
    }

    func fulfill() {
        self.lock.withLock { state in
            switch state {
            case .start(let minFulfillCount):
                let fulfillCount = 1
                if fulfillCount >= minFulfillCount {
                    state = .fulfilled(
                        minFulfillCount: minFulfillCount,
                        fulfillCount: 1
                    )
                } else {
                    state = .partiallyFulfilled(
                        minFulfillCount: minFulfillCount,
                        fulfillCount: 1
                    )
                }
                
            case .partiallyFulfilled(let minFulfillCount, let fulfillCount):
                assert(fulfillCount < minFulfillCount)
                let fulfillCount = fulfillCount + 1
                if fulfillCount >= minFulfillCount {
                    state = .fulfilled(
                        minFulfillCount: minFulfillCount,
                        fulfillCount: fulfillCount
                    )
                } else {
                    state = .partiallyFulfilled(
                        minFulfillCount: minFulfillCount,
                        fulfillCount: fulfillCount
                    )
                }
                
            case .pending(let continuation, let minFulfillCount, let fulfillCount, let timeoutTask):
                var newFulfillCount = fulfillCount + 1
                if newFulfillCount >= minFulfillCount {
                    // fullfilled, we are going to resume the continuation
                    newFulfillCount -= minFulfillCount // consume minFulfillCount
                    timeoutTask?.cancel()
                    if newFulfillCount >= minFulfillCount {
                        state = .fulfilled(
                            minFulfillCount: minFulfillCount,
                            fulfillCount: newFulfillCount
                        )
                    } else {
                        // partially fulfilled
                        state = .partiallyFulfilled(
                            minFulfillCount: minFulfillCount,
                            fulfillCount: newFulfillCount
                        )
                    }
                    continuation.resume(returning: Void())
                } else {
                    // partially fulfilled
                    state = .pending(
                        continuation,
                        minFulfillCount: minFulfillCount,
                        fulfillCount: newFulfillCount,
                        timeoutTask: timeoutTask
                    )
                }
                
            case .fulfilled(let minFulfillCount, let fulfillCount):
                assert(fulfillCount >= minFulfillCount)
                state = .fulfilled(
                    minFulfillCount: minFulfillCount,
                    fulfillCount: fulfillCount + 1
                )
            
            case .rejected:
                return
            }
        }
    }

    

    func fail(with error: any Swift.Error) {
        self.lock.withLock { state in
            switch state {
            case .start:
                state = .rejected(error)
            case .partiallyFulfilled:
                state = .rejected(error)
            case .pending(let continuation, _, _, let timeoutTask):
                timeoutTask?.cancel()
                continuation.resume(throwing: error)
                state = .rejected(error)
            case .rejected, .fulfilled:
                return
            }
        }
    }

    deinit {
        self.lock.withLock { state in
            switch state {
            case .pending(let continuation, _, _, let timeoutTask):
                timeoutTask?.cancel()
                continuation.resume(throwing: Error.deinitalized)
                state = .rejected(Error.deinitalized)
            default:
                break
            }
        }
    }
}


@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension Expectation: CustomStringConvertible {
    public var description: String {
        enum State {
            case unitialized(fulfillCount: Int)
            case pending(Continuation, fulfillCount: Int, timeoutTask: Task<Void, Swift.Error>?)
            case fulfilled
            case rejected(any Swift.Error)
        }

        let description = self.lock.withLock { state in
            return "\(state)"
        }
        
        return "Expectation <\(description)>"
    }
}
