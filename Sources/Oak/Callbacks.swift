public struct Callback<Value: Sendable>: Subject, Sendable {
    let fn: @Sendable @isolated(any) (Value) throws -> Void
    
    public init(_ fn: @escaping @Sendable @isolated(any) (Value) throws -> Void) {
        self.fn = fn
    }

    public init() {
        self.fn = { _ in }
    }

    public func send(_ value: Value) async throws -> Void {
        try await fn(value)
    }
}

public struct NoCallbacks<Value>: Subject {
    public init() {}
    public func send(_ value: Value) throws {}
}
