public protocol Subject<Value>: Sendable {
    associatedtype Value: Sendable
    func send(_ value: Value) async throws
}
