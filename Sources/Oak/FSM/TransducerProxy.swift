import struct Foundation.UUID

/// A `TransducerProxy` represent the transducer interface
/// in a finite state machine which includes the input interface
/// and the ability to terminate the transducer.
public protocol TransducerProxy<Event>: TransducerProxyInternal, Identifiable {
    associatedtype Event
    associatedtype Input

    /// The input interface for the transducer.
    /// This is used to send events to the transducer.
    var input: Input { get }

    /// Terminates the transducer.
    /// 
    /// This method is intended for non-graceful shutdown scenarios of the transducer.
    /// 
    /// After termination, no further events can be sent to the transducer.
    /// - Note: This method is idempotent; calling it multiple times has no effect.
    /// - Important: After termination, the transducer may still process events that were sent before
    /// termination, but no new events can be sent.
    func cancel()
    
    var id: UUID { get }
}

/// Defines the internal API for a Proxy used by a transducer.
///
/// > Warning: All properties and function are intended to be used by the
/// internal transducer implemention only. Accessing them outside is
/// considered a programmer error.
///
/// This protocol is public to allow for custom implementations
/// of a Proxy.

public protocol TransducerProxyInternal<Event> {
    associatedtype Event
    associatedtype Stream: AsyncSequence where Stream.Element == Event
    
    /// Returns the internal stream which is an implementation of
    /// an `AsyncSequence`.
    ///
    /// > Warning:  Do not access this property. This property should
    /// be used by the internal transducer logic only. Accessing it from
    /// outside is considered a programmer error.
    var stream: Stream { get }
    
    /// Performs an invariant check, if available.
    ///
    /// The default implementation does not perform any checks
    /// and returns immediately.
    ///
    /// If it can be implemented, checks whether the proxy is currently
    /// not used by another transducer and that it is not finished.
    /// Otherwise, it should throw an error.
    ///
    /// This prevents illegal uses of the proxy and ensures a given
    /// proxy can be associated once and only once to a tranducer
    /// through passing it as a parameter to the run function.
    ///
    /// When the function succeeded, any further calls should fail.
    ///
    /// > Warning:  Do not call this function. This function should
    /// be used by the internal transducer logic only. Accessing it
    /// from outside is considered a programmer error.
    func checkInUse() throws(TransducerError)
    
    /// Finishes the internal stream.
    ///
    /// - Parameter error: An optional error parameter
    /// indicating the failure reason why the stream has been
    /// finished. Parameter error should be `nil` only when
    /// the transducer finished nornally, i.e. when it reached a
    /// terminal state.
    ///
    /// Once called, the proxy and input values returned from
    /// this proxy should fail when sending events into them.
    ///
    /// > Warning:  Do not call this function. This function should
    /// be used by the internal transducer logic only. Accessing it
    /// from outside is considered a programmer error.
    func finish(error: Swift.Error?)
}

extension TransducerProxyInternal {
    
    /// Finishes the internal stream when the transducer
    /// reached a terminal state.
    ///
    /// Once called, the proxy and input values returned from
    /// this proxy should fail when sending events into them.
    ///
    /// > Warning:  Do not call this function. This function should
    /// be used by the internal transducer logic only. Accessing it
    /// from outside is considered a programmer error.
    public func finish() {
        finish(error: nil)
    }
}

extension TransducerProxyInternal {
    public func checkInUse() throws(TransducerError) {}
}
