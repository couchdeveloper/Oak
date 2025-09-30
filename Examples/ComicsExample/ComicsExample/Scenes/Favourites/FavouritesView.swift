import SwiftUI

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
    @Previewable @State var favourites: [Comics.Comic] = [
        .init(
            id: "1001",
            title: "The Beginning",
            dateString: "2024-01-15",
            imageURL: URL(
                string: "https://example.com/comics/1001.png"
            )!,
            altText: "Protagonist meets a cat",
            isFavourite: true
        ),
        .init(
            id: "1002",
            title: "Plot Twist",
            dateString: "2024-02-02",
            imageURL: URL(
                string: "https://example.com/comics/1002.png"
            )!,
            altText: "A surprising turn of events",
            isFavourite: false
        ),
        .init(
            id: "1003",
            title: "Cliffhanger",
            dateString: "2024-03-10",
            imageURL: URL(
                string: "https://example.com/comics/1003.png"
            )!,
            altText: "Hanging on the edge",
            isFavourite: true
        )
    ]
    
    Favourites.Views.FavouritesView(favourites: favourites)
}

