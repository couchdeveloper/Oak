import struct Foundation.UUID

/// A `TransducerProxy` represent the transducer interface
/// in a finite state machine which includes the input interface
/// and the ability to terminate the transducer.
public protocol TransducerProxy<Event>: Identifiable, Equatable {
    associatedtype Event
    associatedtype Input

    /// A proxy is default-constructible.
    init()

    /// The input interface for the transducer.
    /// This is used to send events to the transducer.
    var input: Input { get }

    /// Terminates the proxy, preventing any further events from being sent and causing
    /// the `run` function to throw an error.
    ///
    /// - Parameter error: An optional error which can be specified by the caller
    /// which the `run` function will throw. If not provided, the `run`should throw
    /// a `TransducerError.cancelled` error.
    ///
    /// This method should only be called when the transducer needs to be shut
    /// down in an ungraceful way. Usually, the transducer will terminate itself
    /// gracefully by processing all events and reaching a terminal state.
    ///
    /// After termination, no further events can be sent to the transducer.
    /// - Note: This method should be idempotent; calling it multiple times should
    /// have no effect.
    func cancel(with error: Swift.Error?)

    var id: UUID { get }
}

extension TransducerProxy {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

extension TransducerProxy {
    public func cancel() {
        cancel(with: TransducerError.cancelled)
    }
}

/// Defines the internal API for a Proxy used by a transducer.
///
/// > Warning: All properties and function are intended to be used by the
/// internal transducer implemention only. Accessing them outside is
/// considered a programmer error.
///
/// This protocol is public to allow for custom implementations
/// of a Proxy.

/// Internal framework protocol - do not implement directly. This protocol provides low-level access to proxy internals
/// required by the framework runtime. Instead, conform to `TransducerProxy` for user-facing proxy implementations.
///
/// The separation between `TransducerProxy` and `TransducerProxyInternal` maintains API boundaries while enabling
/// framework functionality. User code should only interact with the public `TransducerProxy` interface.
///
/// > Important: This protocol is public only to enable framework functionality through generic constraints.
/// > It should not be implemented by user code - conform to `TransducerProxy` instead.
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

    /// Gracefully finishes the proxy's event stream.
    ///
    /// >Caution: This method is intended for internal use by the Oak framework only.
    /// Client code should not call this method directly.
    ///
    /// This function is called by the internal transducer runtime when the state
    /// of the transducer reaches a terminal state, indicating that no further
    /// events will be processed.
    ///
    /// - Important: After calling `finish()`, any subsequent attempts to send
    /// events through this proxy (or its `Input`) will fail because the stream
    /// is terminated.
    ///
    /// - Note: Use `finish()` for normal, graceful shutdowns. If you need to
    /// forcefully terminate processing with an error (e.g. due to an external
    /// cancellation or failure), use `cancel(with:)` instead.
    func finish()
}

extension TransducerProxyInternal {
    public func checkInUse() throws(TransducerError) {}
}
