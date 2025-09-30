import Foundation

// The thing we will render in the FavouriteComicsView
struct FavouriteComic: Identifiable {
    var id: String
    var title: String
    var dateString: String
    var imageURL: URL
    var altText: String
}
