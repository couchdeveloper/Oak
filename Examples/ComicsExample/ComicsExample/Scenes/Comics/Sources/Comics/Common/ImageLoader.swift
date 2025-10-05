enum ImageLoaderError: Swift.Error {
    case `internal`(Swift.Error)
}

protocol ImageLoader {

    typealias URLReference = String

    static func load(url: URLReference) async throws -> Common.PlatformImage
}
