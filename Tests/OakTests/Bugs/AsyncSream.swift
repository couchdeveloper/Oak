//
//  Test.swift
//  Oak
//
//  Created by Andreas Grosam on 07.05.25.
//

/*
/**
 # Issue
 
 ## A Stream will continue to produce elements even when its continuation has been finished
 
 According the documentation for [AsyncThrowingStream.Continuation/finish(throwing:)](https://developer.apple.com/documentation/swift/asyncthrowingstream/continuation/finish(throwing:))
 the associated stream would not produce any elements anymore after the continuation has been finished:
 
 "After calling finish, the stream enters a terminal state and doesn’t produce any additional elements."
 
 However, this is not the observed behaviour:
 When creating a tuple (stream, continuation), then populating the continuation with 1 + N elements,
 and then running an async-for-loop, where after receving the first element the continuation will be
 terminated via calling `finish(throwing:)`, the stream continues to produce _all_ N elements
 which already reside in the underlying buffer before eventually exiting the loop.
 
 The test below demonstrates the observed behaviour above.
 */
import Testing

struct AsyncThrowingStreamTest {
    
    @Test func testStreamDoesNotReturnElementsAfterContinuationFinished() async throws {
        enum Event {
            case start, finish, ping
        }
        enum State {
            case start, running, finished
        }
        
        enum Error: Swift.Error {
            case dropped(Event)
            case terminated
            case unknown
        }

        
        let (stream, continuation) = AsyncThrowingStream<Event, Swift.Error>.makeStream()
        
        continuation.onTermination = { termination in
            print(termination)
        }
        
        // Populate a few events, before we await the for loop.
        // We are not expecting an error here.
        try [.start, .finish, .ping, .ping, .ping].forEach { (event: Event) in
            let result = continuation.yield(event)
            switch result {
            case .enqueued:
                break
            case .dropped(let event):
                throw Error.dropped(event)
            case .terminated:
                throw Error.terminated
            default:
                throw Error.unknown
            }
        }
        
        // When receiving element `finish` we finish the continuation.
        // So I would expect any element after `finish` (i.e, `ping`s)
        // will not be produced.
        var state = State.start
        var count = 0
        loop: for try await event in stream {
            switch (event, state) {
            case (.start, .start):
                state = .running
            case (.finish, .running):
                state = .finished
                continuation.finish(throwing: nil)
                // We could break here to exit the for loop, like in the comment below:
                break loop
                // However, I expect the loop to exit anyway because of termination
                // of the continuation via `continuation.finish(throwing: nil)`,
                // according the doc:
                // "After calling finish, the stream enters a terminal state
                // and doesn’t produce any additional elements."
                // So, I do not expect to receive any further elements.
            case (_, .finished):
                // Uhps!
                count += 1
                Issue.record("Received an element (\(count)) (aka event: '\(event)') after the continuation has been finished.")
            case (.ping, .start):
                break
            case (.ping, .running):
                break
            case (.finish, .start):
                break
            case (.start, .running):
                break
            }
        }
        
        // drain the input queue:
        var ignoreCount = 0
        for try await event in stream {
            ignoreCount += 1
            print("Ignored an element (\(ignoreCount)) (aka event: '\(event)') after the continuation has been finished.")
        }
    }

}


struct AsyncStreamTest {
    
    @Test func testStreamDoesNotReturnElementsAfterContinuationFinished() async throws {
        enum Event {
            case start, finish, ping
        }
        enum State {
            case start, running, finished
        }
        
        enum Error: Swift.Error {
            case dropped(Event)
            case terminated
            case unknown
        }

        
        let (stream, continuation) = AsyncStream<Event>.makeStream()
        
        continuation.onTermination = { termination in
            print(termination)
        }
        
        // Populate a few events, before we await the for loop.
        // We are not expecting an error here.
        try [.start, .finish, .ping, .ping, .ping].forEach { (event: Event) in
            let result = continuation.yield(event)
            switch result {
            case .enqueued:
                break
            case .dropped(let event):
                throw Error.dropped(event)
            case .terminated:
                throw Error.terminated
            default:
                throw Error.unknown
            }
        }
        
        // When receiving element `finish` we finish the continuation.
        // So I would expect any element after `finish` (i.e, `ping`s)
        // will not be produced.
        var state = State.start
        var count = 0
        loop: for await event in stream {
            switch (event, state) {
            case (.start, .start):
                state = .running
            case (.finish, .running):
                state = .finished
                continuation.finish()
                // We could break here to exit the for loop, like in the comment below:
                // break loop
                // However, I expect the loop to exit anyway because of termination
                // of the continuation via `continuation.finish(throwing: nil)`,
                // according the doc:
                // "After calling finish, the stream enters a terminal state
                // and doesn’t produce any additional elements."
                // So, I do not expect to receive any further elements.
            case (_, .finished):
                // Uhps!
                count += 1
                Issue.record("Received an element (\(count)) (aka event: '\(event)') after the continuation has been finished.")
            case (.ping, .start):
                break
            case (.ping, .running):
                break
            case (.finish, .start):
                break
            case (.start, .running):
                break
            }
        }
    }

}


import Testing

protocol Subject<Value> {
    associatedtype Value
    func send(_ value: Value)
}

protocol P {
    associatedtype V
    
    static func foo<S: Subject<V>>(subject: S)
}

struct DefaultSubject<Value>: Subject {
    func send(_ value: Value) {}
}

extension P {
    static func foo(subject: some Subject<V> = DefaultSubject<V>()) { }
    // static func foo() { foo(subject: DefaultSubject()) }
    // static func foo<S: Subject<V>>(subject: S = DefaultSubject<V>()) {}
    static func foo() { foo(subject: DefaultSubject()) }
}

enum E: P {
    typealias V = Int
}

@Test func test() async throws {
    
    E.foo(subject: DefaultSubject()) // fine!
    E.foo() // Generic parameter 'S' could not be inferred
    
    let defaultParam = DefaultSubject<E.V>()
    E.foo(subject: defaultParam)
}
*/
