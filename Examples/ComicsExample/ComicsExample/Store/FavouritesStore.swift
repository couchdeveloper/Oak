import Combine

enum FavouritesStoreError: Swift.Error {
    case notFound
    case invalidId
    case `internal`(Swift.Error)
}

protocol FavouritesStore: AnyObject {
    typealias Error = FavouritesStoreError

    associatedtype Favourite: Identifiable
    associatedtype Asset
    typealias ID = Favourite.ID

    func isFavourite(withId: ID) -> AnyPublisher<Bool, Error>
    func toggleFavourite(_ favourite: Favourite) -> AnyPublisher<Bool, Error>
    func setFavourite(_ favourite: Favourite) -> AnyPublisher<Void, Error>
    func unsetFavourite(withId: ID) -> AnyPublisher<Void, Error>
    func loadAsset(for favourite: Favourite) -> AnyPublisher<Asset, Error>
    func all() -> AnyPublisher<Set<ID>, Error>
}

class AnyFavouritesStore<Favourite: Identifiable, Asset>: FavouritesStore {

    typealias Error = FavouritesStore.Error

    private let _isFavourite: (ID) -> AnyPublisher<Bool, Error>
    private let _toggleFavourite: (Favourite) -> AnyPublisher<Bool, Error>
    private let _setFavourite: (Favourite) -> AnyPublisher<Void, Error>
    private let _unsetFavourite: (ID) -> AnyPublisher<Void, Error>
    private let _loadAsset: (Favourite) -> AnyPublisher<Asset, Error>
    private let _all: () -> AnyPublisher<Set<ID>, Error>


    public init<WrappedFavouritesStore: FavouritesStore>(wrappedFavouriteStore: WrappedFavouritesStore)
        where WrappedFavouritesStore.Favourite == Favourite, WrappedFavouritesStore.Asset == Asset
    {
        _isFavourite = wrappedFavouriteStore.isFavourite
        _toggleFavourite = wrappedFavouriteStore.toggleFavourite
        _setFavourite = wrappedFavouriteStore.setFavourite
        _unsetFavourite = wrappedFavouriteStore.unsetFavourite
        _loadAsset = wrappedFavouriteStore.loadAsset
        _all = wrappedFavouriteStore.all
    }

    func isFavourite(withId id: ID) -> AnyPublisher<Bool, Error> {
        _isFavourite(id)
    }

    func toggleFavourite(_ favourite: Favourite) -> AnyPublisher<Bool, Error> {
        _toggleFavourite(favourite)
    }

    func setFavourite(_ favourite: Favourite) -> AnyPublisher<Void, Error> {
        _setFavourite(favourite)
    }

    func unsetFavourite(withId id: ID) -> AnyPublisher<Void, Error> {
        _unsetFavourite(id)
    }

    func loadAsset(for favourite: Favourite) -> AnyPublisher<Asset, Error> {
        _loadAsset(favourite)
    }

    func all() -> AnyPublisher<Set<ID>, Error> {
        _all()
    }
}

extension FavouritesStore {
    func eraseToAnyFavouriteStore() -> AnyFavouritesStore<Self.Favourite, Self.Asset> {
        return AnyFavouritesStore(wrappedFavouriteStore: self)
    }
}
