
#if false
import Foundation
import SwiftUI

extension UserDefaults {

    // MARK: Comic Favourites

    @UserDefault(key: "comic.favourites", defaultValue: Set<Int>())
    static var comicFavourites: Set<Int>


    static func toggleFavourite(for index: Int) -> Bool {
        if comicFavourites.contains(index) {
            comicFavourites.remove(index)
            return false
        } else {
            comicFavourites.insert(index)
            return true
        }
    }

    static func isFavourite(id: Int) -> Bool {
        return comicFavourites.contains(id)
    }
}

#endif
