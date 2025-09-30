#if false
import Combine
import MVVM


extension Effects {

    enum FavouriteStore {

        static func all<Entity: Identifiable, Asset>(store: AnyFavouritesStore<Entity, Asset>) -> Effect<Void, [Entity.ID], Swift.Error> {
            return .init {
                store.all()
                    .map { Array<Entity.ID>($0) }
                    .mapError { $0 as Swift.Error }
                    .eraseToAnyPublisher()
            }
        }

        static func unsetFavourite<Entity: Identifiable, Asset>(id: Entity.ID, store: AnyFavouritesStore<Entity, Asset>) -> Effect<Entity.ID, Void, Swift.Error> {
            return .init { id in
                store.unsetFavourite(withId: id)
                    .mapError { $0 as Swift.Error }
                    .eraseToAnyPublisher()
            }
        }

    }

}
#endif
