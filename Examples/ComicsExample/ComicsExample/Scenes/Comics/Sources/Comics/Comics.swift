import Foundation

// MARK: - Public API

public enum ComicsError: Swift.Error, LocalizedError {
    case notFound(id: Int, underlyingError: Swift.Error? = nil)
    case other(Swift.Error)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id, _):
            return "Comic #\(id) not found."
        case .other(let error):
            return error.localizedDescription
        }
    }
}

public struct ComicsEnv: Sendable {
    // Note: In order to adhere to IoC, services shall not expose any symbols
    // from the underlying service to the transducer. This also includes errors.
    // Thus, we need to map the ComicAPI errors to Transducer.Error within
    // the layer implementing the below functions.
    
    public init(
        loadComic: @Sendable @escaping (Int) async throws(ComicsError) -> Comic,
        loadActualComic: @Sendable @escaping () async throws(ComicsError) -> Comic
    ) {
        self.loadComic = loadComic
        self.loadActualComic = loadActualComic
    }

    var loadComic: @Sendable (Int) async throws(ComicsError) -> Comic
    var loadActualComic: @Sendable () async throws(ComicsError) -> Comic
}
    
public struct Comic: Identifiable {
    public init(
        id: Int,
        title: String,
        date: Date?,
        imageURL: URL,
        altText: String,
        isFavourite: Bool
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.imageURL = imageURL
        self.altText = altText
        self.isFavourite = isFavourite
    }
    
    public var id: Int
    public var title: String
    public var date: Date?
    public var imageURL: URL
    public var altText: String
    public var isFavourite: Bool
}

extension Comic: Equatable {}
