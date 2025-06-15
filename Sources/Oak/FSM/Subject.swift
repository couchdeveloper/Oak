
/// A type that can receive input values.
public protocol Subject<Value>: Sendable {
    /// The type of the input value.
    associatedtype Value: Sendable
    
    /// Sends the value `value` to `Self`.
    func send(_ value: Value) async throws
}
