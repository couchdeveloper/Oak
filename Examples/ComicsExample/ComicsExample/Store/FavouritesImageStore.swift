import Combine
import class UIKit.UIImage

class FavouritesImageStore: FavouritesStore {

    typealias Favourite = Comic
    typealias Asset = UIImage
    typealias Error = FavouritesStoreError

    static let shared = FavouritesImageStore()

    private let store: FileStore

    init(albumName: String = "MyFavourites") {
        self.store = .init(album: albumName)
    }

    func isFavourite(withId id: String) -> AnyPublisher<Bool, Error> {
        return Just(store.exists(at: id)).setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func toggleFavourite(_ favourite: Comic) -> AnyPublisher<Bool, Error> {
        if self.store.exists(at: favourite.id) {
            return unsetFavourite(withId: favourite.id).map { _ in false }.eraseToAnyPublisher()
        } else {
            return setFavourite(favourite).map { _ in true }.eraseToAnyPublisher()
        }
    }

    func setFavourite(_ favourite: Comic) -> AnyPublisher<Void, Error> {
        return NukeImageLoader.default.load(string: favourite.imageURL.absoluteString)
        .flatMap { image in
            return self.store.save(image, with: favourite.id).mapError(ImageLoaderError.internal)
        }.mapError(Error.internal)
        .map { image in
            print(image)
        }
        .eraseToAnyPublisher()
    }

    func unsetFavourite(withId id: ID) -> AnyPublisher<Void, Error> {
        return self.store.delete(at: id)
        .mapError(Error.internal)
        .eraseToAnyPublisher()
    }

    func loadAsset(for favourite: Comic) -> AnyPublisher<UIImage, Error> {
        // loads the image from the favourites store - not from the API
        return store.load(at: favourite.id)
            .mapError { storeError in
                if case .notFound = storeError {
                    return Error.notFound
                }
                return Error.internal(storeError)
            }
            .eraseToAnyPublisher()
    }

    func all() -> AnyPublisher<Set<ID>, Error> {
        return store.all().mapError(Error.internal).eraseToAnyPublisher()
    }

}
