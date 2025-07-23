/// A `Callback` value encapsulates an isolated closure which takes a parameter of
/// type `value` as an argument.
///
///  An `Callback` is used by a transducer to send it's output values which will be
///  handled by the closure.
public struct Callback<Value>: Subject {
    let fn: @Sendable @isolated(any) (sending Value) async throws -> Void
    
    /// Initialises a `Callback` value with the given isolated throwing closure.
    ///
    /// - Parameter fn: An async throwing closure which will be called when `Self`
    /// receives a value via its `send(_:)` function.
    public init(_ fn: @Sendable @escaping @isolated(any) (Value) async throws -> Void) {
        self.fn = fn
    }

    /// Send a value to `Self` which calls its callback clouser with the argument `value`.
    /// - Parameter value: The value which is used as the argument to the callback closure.
    /// - Parameter isolated: The "system actor" where this function is being called on.
    public func send(_ value: sending Value, isolated: isolated (any Actor)? = #isolation) async throws {
        try await fn(value)
    }
}

extension Callback: Sendable where Value: Sendable {}

/// A convenient struct which defines a `Callback` value whose closure is a no-op.
public struct NoCallback<Value>: Subject {
    public init() {}
    /// Sending the value has no effect.
    public func send(_ value: sending Value, isolated: isolated (any Actor)? = #isolation) async {}
}
