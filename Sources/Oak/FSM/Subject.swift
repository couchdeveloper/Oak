
/// A type that can receive values and send it to a destination.
public protocol Subject<Value> {
    /// The type of the input value.
    associatedtype Value
    
    /// Sends the value `value` to `Self`.
    ///
    /// Sends a value into the subject and suspends until it
    /// is successfully delivered to the destination.
    ///
    /// - Parameter value: The value which should be send to the destination.
    /// - Throws: When the value could not be delivered to the destination, it throws an error.
    func send(_ value: sending Value, isolated: isolated (any Actor)?) async throws
}
