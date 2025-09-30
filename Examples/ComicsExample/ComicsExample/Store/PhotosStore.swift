import UIKit
import Combine
import Photos

// NOTE: PhotosStore cannot be implemented conforming to protocol `Store`
// on *iOS* because there is no way to find a specific image searched by meta
// data.
// Thus, function
// `func load(at index: Int) -> AnyPublisher<UIImage, StoreError>` and
// `func delete(at index: Int) -> AnyPublisher<Void, StoreError>`
// cannot be implemented.

class PhotosStore: NSObject, Store {

    typealias Element = UIImage

    private let albumTitle: String

    init(album: String) {
        self.albumTitle = album
        super.init()
        PHPhotoLibrary.shared().register(self as PHPhotoLibraryAvailabilityObserver)
        PHPhotoLibrary.shared().register(self as PHPhotoLibraryChangeObserver)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self as PHPhotoLibraryChangeObserver)
    }

    func load(at index: Int) -> AnyPublisher<UIImage, StoreError> {
        Fail(error: .internal("not supported")).eraseToAnyPublisher()
    }

    func delete(at index: Int) -> AnyPublisher<Void, StoreError> {
        Fail(error: .internal("not supported")).eraseToAnyPublisher()

    }

    func save(_ element: UIImage, with index: Int) -> AnyPublisher<UIImage, StoreError> {
        album(title: self.albumTitle)
        .flatMap { album in
            album.save(element)
        }
        .map { asset in
            print(asset)
            return element
        }
        .mapError(StoreError.internal)
        .eraseToAnyPublisher()
    }

    // MARK: - private

    private func album(title: String) -> AnyPublisher<PHAssetCollection, Swift.Error> {
        if let album = getAlbum(title: title) {
            return Just(album).setFailureType(to: Swift.Error.self).eraseToAnyPublisher()
        } else {
            return createAlbum(title: title)
        }
    }

    private func getAlbum(title: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", title)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        return collections.firstObject
    }

    private func createAlbum(title: String) -> AnyPublisher<PHAssetCollection, Swift.Error> {
        return Future() { promise in
            var future: PHObjectPlaceholder!
            PHPhotoLibrary.shared().performChanges {
                let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                future = createAlbumRequest.placeholderForCreatedAssetCollection
            } completionHandler: { success, error in
                if let error = error {
                    promise(.failure(StoreError.internal(error)))
                }
                guard let album = future.collection else {
                    promise(.failure(StoreError.internal("Could not create album with title \(title)")))
                    return
                }
                promise(.success(album))
            }
        }.eraseToAnyPublisher()
    }

}

extension PhotosStore: PHPhotoLibraryAvailabilityObserver, PHPhotoLibraryChangeObserver {

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        print("photoLibraryDidChange: \(changeInstance)")
    }

    func photoLibraryDidBecomeUnavailable(_ photoLibrary: PHPhotoLibrary) {
        print("photoLibraryDidBecomeUnavailable: \(photoLibrary)")
    }

}

extension PHAssetCollection {

    func save(_ image: UIImage) -> AnyPublisher<PHAsset, Swift.Error> {
        var future: PHObjectPlaceholder!
        return Future() { promise in
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                guard let collectionChangeRequest = PHAssetCollectionChangeRequest.init(for: self) else {
                    promise(.failure("Could not create a PHAssetCollectionChangeRequest"))
                    return
                }
                // Get a placeholder for the asset which is to be added and add it to the album editing request.
                future = creationRequest.placeholderForCreatedAsset!
                collectionChangeRequest.addAssets([future!] as NSArray)
            } completionHandler: { success, error in
                if let error = error {
                    promise(.failure(error))
                }
                if let asset = future.asset {
                    promise(.success(asset))
                } else {
                    promise(.failure("Could not save image"))
                }
            }
        }.eraseToAnyPublisher()
    }

}

extension PHObjectPlaceholder {

    var asset: PHAsset? {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [self.localIdentifier],
            options: nil)
        return fetchResult.firstObject
    }

    var collection: PHAssetCollection? {
        let fetchResult = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [self.localIdentifier],
            options: nil)
        return fetchResult.firstObject
    }

}
