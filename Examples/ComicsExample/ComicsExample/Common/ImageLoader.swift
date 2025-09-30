enum ImageLoaderError: Swift.Error {
    case `internal`(Swift.Error)
}

protocol ImageLoader {

    typealias URLReference = String

    static var `default`: ImageLoader { get }

    func load(string: URLReference) throws -> PlatformImage

}
