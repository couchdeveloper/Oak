import Combine

public enum StoreError: Swift.Error {
    case notFound
    case `internal`(Swift.Error)
}

public protocol Store {
    associatedtype Element
    associatedtype ID
    func load(at: ID) -> AnyPublisher<Element, StoreError>
    func delete(at: ID) -> AnyPublisher<Void, StoreError>
    func save(_ element: Element, with: ID) -> AnyPublisher<Element, StoreError>
}
