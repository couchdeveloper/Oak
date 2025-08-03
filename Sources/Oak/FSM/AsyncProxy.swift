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
    public let id: UUID = UUID()

    enum Error: Swift.Error {
        case terminated
        case deinitialised
    }

    public let stream: AsyncThrowingChannel<Event, Swift.Error>

    public struct Input: SyncSuspendingTransducerInput {
        let channel: AsyncThrowingChannel<Event, Swift.Error>

        public func send(_ event: Event) async {
            await channel.send(event)
        }
    }

    public final class AutoCancellation: Sendable, Equatable {
        public static func == (lhs: AutoCancellation, rhs: AutoCancellation) -> Bool {
            lhs.id == rhs.id
        }

        let stream: Stream
        let id: SyncSuspendingProxy.ID

        init(proxy: SyncSuspendingProxy) {
            stream = proxy.stream
            id = proxy.id
        }

        deinit {
            stream.fail(SyncSuspendingProxy<Event>.Error.deinitialised)
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

    public var autoCancellation: AutoCancellation {
        .init(proxy: self)
    }

    public func cancel(with error: Swift.Error? = nil) {
        stream.fail(error ?? TransducerError.cancelled)
    }

    public func finish() {
        stream.finish()
    }

}
