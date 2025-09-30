import Foundation

extension DTO {
    // The JSON received from endpoints representing a "Comic"
    struct Comic: Decodable {
        var num: Int
        var title: String
        var img: URL
        var day: String
        var month: String
        var year: String
        var news: String
        var safe_title: String
        var transcript: String
        var alt: String
        var link: String
    }
}
