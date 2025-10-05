#if false
import SwiftUI
import Comics

extension Favourites { enum Views {} }


extension Favourites.Views {
    
    struct FavouritesView: View {
        let favourites: [Comics.Comic]
        var body: some View {
            List(favourites, id: \.id) { comic in
                Text(comic.title)
            }
        }
    }
    
}

// MARK: - Previews

#Preview("FavouritesView") {
    Favourites.Views.FavouritesView(favourites: Mocks.favourites)
}

#endif
