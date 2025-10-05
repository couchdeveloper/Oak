import Foundation

extension DTO {
    // The JSON received from endpoints representing a "Comic"
    public struct Comic: Decodable, Sendable {
        public var num: Int
        public var title: String
        public var img: URL
        public var day: String
        public var month: String
        public var year: String
        public var news: String
        public var safe_title: String
        public var transcript: String
        public var alt: String
        public var link: String
    }
}
