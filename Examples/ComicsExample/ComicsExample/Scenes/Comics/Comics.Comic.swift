import Foundation

extension Comics {
    
    // The thing that will be rendered in the ComicView
    public struct Comic: Identifiable {
        public var id: String
        public var title: String
        public var dateString: String
        public var imageURL: URL
        public var altText: String
        public var isFavourite: Bool
    }
}

extension Comics.Comic: Equatable {}
