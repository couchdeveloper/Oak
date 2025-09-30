import Combine

extension Mock {

    class MockStore<Element: Hashable>: Store {
        var store: Dictionary<Int, Element>

        init(with store: Dictionary<Int, Element> = [:]) {
            self.store = store
        }

        func load(at index: Int) -> AnyPublisher<Element, StoreError> {
            if let element = self.store[index] {
                return Just(element)
                    .setFailureType(to: StoreError.self)
                    .eraseToAnyPublisher()
            } else {
                return Fail(error: StoreError.notFound).eraseToAnyPublisher()
            }
        }

        func delete(at index: Int) -> AnyPublisher<Void, StoreError> {
            if let _ = self.store[index] {
                self.store[index] = nil
                return Just(Void())
                    .setFailureType(to: StoreError.self)
                    .eraseToAnyPublisher()
            } else {
                return Fail(error: StoreError.notFound).eraseToAnyPublisher()
            }
        }

        func save(_ element: Element, with index: Int) -> AnyPublisher<Element, StoreError> {
            self.store[index] = element
            return Just(element)
                .setFailureType(to: StoreError.self)
                .eraseToAnyPublisher()
        }

    }

}
