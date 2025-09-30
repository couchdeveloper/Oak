import Foundation
import class UIKit.UIImage
import Combine

struct FileStore: Store {
    private let albumUrl: URL

    init(album: String) {
        self.albumUrl = FileStore.createAlbumDirectoryIfRequired(name: album)
    }

    func load(at id: String) -> AnyPublisher<UIImage, StoreError> {
        do {
            let data = try Data(contentsOf: URL(string: id, relativeTo: albumUrl)!)
            guard let image = UIImage(data: data) else {
                throw "could not decode image"
            }
            return Just(image).setFailureType(to: StoreError.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: .internal(error)).eraseToAnyPublisher()
        }

    }

    func delete(at id: String) -> AnyPublisher<Void, StoreError> {
        do {
            let fileUrl = self.albumUrl.appendingPathComponent(id)
            try FileManager.default.removeItem(at: fileUrl)
            return Just(Void()).setFailureType(to: StoreError.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: .internal(error)).eraseToAnyPublisher()
        }
    }

    func save(_ element: UIImage, with id: String) -> AnyPublisher<UIImage, StoreError> {
        do {
            let fileUrl = self.albumUrl.appendingPathComponent(id)
            guard let data = element.pngData() else {
                throw "could not encode image"
            }
            try data.write(to: fileUrl)
            assert(exists(at: id))
            print("Favourite written at: \(fileUrl.absoluteURL)")

            return Just(element).setFailureType(to: StoreError.self).eraseToAnyPublisher()
        } catch {
            print("ERROR: \(error)")
            return Fail(error: .internal(error)).eraseToAnyPublisher()
        }
    }

}

extension FileStore {
    static func createAlbumDirectoryIfRequired(name: String) -> URL {
        let picturesDirectory = NSSearchPathForDirectoriesInDomains(.picturesDirectory, .userDomainMask, true).first!
        let url = URL(fileURLWithPath: picturesDirectory)
        let albumUrl = url.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: albumUrl.path) {
            do {
                try FileManager.default.createDirectory(atPath: albumUrl.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
        return albumUrl
    }
}


extension FileStore {
    func exists(at id: String) -> Bool {
        let url = albumUrl.appendingPathComponent(id)
        return FileManager.default.fileExists(atPath: url.path)
    }

    func all() -> AnyPublisher<Set<String>, StoreError> {
        do {
            let ids = try FileManager.default.contentsOfDirectory(
                at: albumUrl,
                includingPropertiesForKeys: nil)
                .map { $0.lastPathComponent }
            return Just(Set(ids)).setFailureType(to: StoreError.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: .internal(error)).eraseToAnyPublisher()
        }
    }
}
