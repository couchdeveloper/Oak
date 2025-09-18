/// A type that can receive values and send it to a destination.
///
/// ## Overview
///
/// The `Subject` protocol serves as the output facility for transducers, providing a unified API
/// for transducers to send values without knowing the specific implementation details of how those
/// values are consumed or processed.
///
/// From the transducer's perspective, this protocol offers a simple interface to emit output values.
/// From the user's perspective, this abstraction allows for flexible consumption patterns through
/// various concrete implementations.
///
/// ## Common Implementations
///
/// The Oak library provides built-in implementations:
///
/// - **`Callback`**: Direct function-based value consumption
/// - **`NoCallback`**: A no-op implementation for when output values should be discarded
///
/// Additional implementations can include:
///
/// - **AsyncStream**: Stream-based asynchronous value consumption
/// - **Combine Subject**: Integration with the Combine framework for reactive programming
/// - **Custom Consumers**: Any type that needs to consume values from a transducer
///
/// ## Usage Pattern
///
/// Transducers use this protocol to emit output values without coupling to specific consumption mechanisms:
///
/// ```swift
/// // Transducer sends output through the subject
/// try await output.send(computedValue, isolated: systemActor)
/// ```
///
/// Users can provide different subject implementations based on their consumption needs:
///
/// ```swift
/// // Using the provided Callback type
/// let callback = Callback<String> { value in
///     print("Received: \(value)")
/// }
///
/// // Using NoCallback when output should be discarded
/// let noOutput = NoCallback<String>()
///
/// // Using with an AsyncStream
/// let (stream, continuation) = AsyncStream.makeStream(of: String.self)
/// let streamSubject = AsyncStreamSubject(continuation)
/// ```
///
public protocol Subject<Value> {
    /// The type of the input value.
    associatedtype Value

    /// Sends the value `value` to `Self`.
    ///
    /// Sends a value into the subject and suspends until it
    /// is successfully delivered to the destination.
    ///
    /// - Parameter value: The value which should be send to the destination.
    /// - Parameter isolated: The actor isolation context for the send operation.
    /// - Throws: When the value could not be delivered to the destination, it throws an error.
    func send(_ value: sending Value, isolated: isolated any Actor) async throws
}
