/// A `Callback` value encapsulates an isolated closure which takes a parameter of
/// type `value` as an argument.
public struct Callback<Value>: Subject {
    let fn: @Sendable @isolated(any) (sending Value) throws -> Void
    
    /// Initialises a `Callback` value with the given isolated throwing closure.
    ///
    /// - Parameter fn: A throwing closure which will be called when `Self`
    /// receives a value via its `send(_:)` function.
    public init(_ fn: @escaping @Sendable @isolated(any) (sending Value) throws -> Void) {
        self.fn = fn
    }

    /// Initialises a `Callback` value with a no-op closure.
    public init() {
        self.fn = { _ in }
    }
    
    /// Send a value to `Self` which calls its callback clouser with the argument `value`.
    /// - Parameter value: The value which is used as the argument to the callback closure.
    public func send(_ value: sending Value) async throws {
        try await fn(value)
    }
}

extension Callback: Sendable where Value: Sendable {}

/// A convenient struct which defines a `Callback` value whose closure is a no-op.
public struct NoCallbacks<Value>: Subject {
    public init() {}
    /// Sending the value has no effect.
    public func send(_ value: sending Value) async throws {}
}
