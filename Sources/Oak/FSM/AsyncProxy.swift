import AsyncAlgorithms
import struct Foundation.UUID

/// `AsyncProxy` is a proxy that sends events into the system using
/// an  async non-throwing function.
///
/// When explicitly defining the Proxy type `FSM.AsyncProxy<Event>`
/// in the `EventTransducer`, we are using an `AsyncProxy` for sending
/// events into the system. This event delivery mechansism uses an async
/// function to deliver the event that suspends until after the event
/// has been processed. This also includes being suspended until the
/// delivery of an output value (through a Subject) has been completed.
/// Thus, sending an event will never fail, but it may be delayed as
/// needed.
/// The processing speed of the transducer will be dynamically adjusted
/// so that it is synchronised with its event producers and its output
/// consumers through utilising suspension.
public struct AsyncProxy<Event: Sendable>: TransducerProxy {
    public let id: UUID = UUID()
    
    enum Error: Swift.Error {
        case terminated
    }
    
    public let stream: AsyncThrowingChannel<Event, Swift.Error>
            
    public struct Input: AsyncTransducerInput {
        let channel: AsyncThrowingChannel<Event, Swift.Error>
        
        public func send(_ event: Event) async {
            await channel.send(event)
        }
    }
    
    public init() {
        self.stream = .init()
    }
        
    public func send(_ event: Event) async {
        await stream.send(event)
    }

    public func send(events: (() -> Event)...) async {
        for event in events {
            await self.send(event())
        }
    }
    
    public var input: Input {
        .init(channel: self.stream)
    }
    
    public func cancel() {
        stream.fail(Error.terminated)
    }
    
    public func finish(error: Swift.Error? = nil) {
        if let error = error {
            stream.fail(error)
        } else {
            stream.finish()
        }   
    }

}
