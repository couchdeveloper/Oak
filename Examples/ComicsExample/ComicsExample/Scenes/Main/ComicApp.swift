import SwiftUI
import class UIKit.UIImage
// import ComicSelection
// import Favourites

let favouritesStore = FavouritesImageStore().eraseToAnyFavouriteStore()
let favouritesViewModel = FavouritesSceneViewModel(favouritesStore: favouritesStore).eraseToAnyViewModel()

let comicsViewModel = ComicSelectionViewModel(favouritesStore: favouritesStore).eraseToAnyViewModel()

struct MainView: View {

    var body: some View {
        TabView {
            ComicSelectionView(viewModel: comicsViewModel)
            .tabItem {
                Image(systemName: "rectangle.on.rectangle.angled")
                Text("Comics")
            }
            FavouritesSceneView(viewModel: favouritesViewModel)
            .tabItem {
                Image(systemName: "heart.fill")
                Text("Favourites")
            }
        }
        .font(.headline)
    }
}
