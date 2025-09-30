import Combine

public struct AnyStore<Element, ID>: Store {

    private let _load: (ID) -> AnyPublisher<Element, StoreError>
    private let  _delete: (ID) -> AnyPublisher<Void, StoreError>
    private let _save: (Element, ID) -> AnyPublisher<Element, StoreError>


    public init<WrappedStore: Store>(wrappedStore: WrappedStore)
    where WrappedStore.Element == Element, WrappedStore.ID == ID
    {
        _load = wrappedStore.load
        _delete = wrappedStore.delete
        _save = wrappedStore.save
    }

    public func load(at id: ID) -> AnyPublisher<Element, StoreError> {
        _load(id)
    }

    public func delete(at id: ID) -> AnyPublisher<Void, StoreError> {
        _delete(id)
    }

    public func save(_ element: Element, with id: ID) -> AnyPublisher<Element, StoreError> {
        _save(element, id)
    }

}

public extension Store {
    func eraseToAnyStore() -> AnyStore<Self.Element, Self.ID> {
        return AnyStore(wrappedStore: self)
    }
}
