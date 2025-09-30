import Foundation

enum HTTPClient {
    
    static let decoder = JSONDecoder()

    static func get<T: Decodable>(type: T.Type = T.self, url: URL) async throws -> T {
        // NSLog("<<< HTTP GET \(url.absoluteURL)")

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            fatalError("invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            throw "Network: invalid status code \(httpResponse.statusCode) (\(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)))"
        }
        let value: T = try JSONDecoder().decode(T.self, from: data)
        return value
    }
}
