import Foundation

public enum HttpClient {
    
    public enum Error: Swift.Error {
        case notFound
        case unexpectedHttpStatusCode(Int, underlyingError: Swift.Error? = nil)
        case decoderError(underlyingError: Swift.Error?)
        case urlError(URLError)
        case other(underlyingError: Swift.Error)
    }


    static let decoder = JSONDecoder()

    public static func get<T: Decodable>(type: T.Type = T.self, url: URL) async throws(HttpClient.Error) -> T {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                fatalError("invalid response")
            }
            switch httpResponse.statusCode {
            case 200:
                break
            case 404 /*not found*/:
                throw Error.notFound
            default:
                throw Error.unexpectedHttpStatusCode(httpResponse.statusCode)
            }
            do {
                let value: T = try JSONDecoder().decode(T.self, from: data)
                return value
            } catch {
                throw Error.decoderError(underlyingError: error)
            }
        } catch let error where error is HttpClient.Error {
            throw error as! HttpClient.Error
        } catch let error where error is URLError {
            throw .urlError(error as! URLError)
        } catch {
            throw .other(underlyingError: error)
        }
    }
}
