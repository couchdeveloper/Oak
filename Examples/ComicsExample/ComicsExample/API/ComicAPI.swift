import Foundation
// import HTTPClient

struct ComicAPI {

    enum Error: Swift.Error {
        case `internal`(Swift.Error)
    }

    static let baseURL = URL(string: "https://xkcd.com")!

    static func actualComic() async throws -> DTO.Comic {
        do {
            return try await HTTPClient.get(url: makeURL())
        } catch {
            throw Error.internal(error)
        }
    }

    static func comic(with index: Int) async throws -> DTO.Comic {
        do {
            return try await HTTPClient.get(url: makeURL(from: index))
        } catch {
            throw Error.internal(error)
        }
    }

    static func comic(_ index: Int? = nil) async throws -> DTO.Comic {
        if let index = index {
            try await comic(with: index)
        } else {
            try await actualComic()
        }
    }

    static func comics(ids: [Int]) async throws -> [DTO.Comic] {
        guard ids.count > 0 else {
            return []
        }
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
