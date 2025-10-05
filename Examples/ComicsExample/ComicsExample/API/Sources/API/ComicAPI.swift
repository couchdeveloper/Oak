import Foundation
import HTTPClient

public struct ComicAPI {

    public enum Error: Swift.Error {
        case notFound(id: Int)
        case `internal`(Swift.Error)
    }

    public static let baseURL = URL(string: "https://xkcd.com")!

    public static func actualComic() async throws(Error) -> DTO.Comic {
        do {
            return try await HttpClient.get(url: makeURL())
        } catch {
            throw Error.internal(error)
        }
    }

    public static func comic(with index: Int) async throws(Error) -> DTO.Comic {
        do {
            return try await HttpClient.get(url: makeURL(from: index))
        } catch HttpClient.Error.notFound {
            throw .notFound(id: index)
        } catch {
            throw Error.internal(error)
        }
    }

    public static func comic(_ index: Int? = nil) async throws(Error) -> DTO.Comic {
        if let index = index {
            return try await comic(with: index)
        } else {
            return try await actualComic()
        }
    }

    public static func comics(ids: [Int]) async throws(Error) -> [DTO.Comic] {
        guard !ids.isEmpty else {
            return []
        }
        do {
            return try await withThrowingTaskGroup(
                of: DTO.Comic.self,
                returning: [DTO.Comic].self
            ) { group in
                ids.forEach { id in
                    group.addTask {
                        try await ComicAPI.comic(with: id)
                    }
                }
                var comics: [DTO.Comic] = []
                for try await comic in group {
                    comics.append(comic)
                }
                return comics
            }
        } catch let error as ComicAPI.Error {
            throw error
        } catch {
            throw Error.internal(error)
        }
    }
}

private extension ComicAPI {

    static func makeURL(from index: Int? = nil) -> URL {
        return composeURL(urlReference: urlReference(with: index))
    }

    static func composeURL(urlReference: String) -> URL {
        return URL(string: urlReference, relativeTo: baseURL)!
    }

    static func urlReference(with index: Int?) -> String {
        if let index = index {
            return "\(index)/info.0.json"
        } else {
            return "info.0.json"
        }
    }
}
