import SwiftUI
import Comics
import Services
// import Favourites

// let favouritesStore = FavouritesImageStore().eraseToAnyFavouriteStore()

public struct MainView: View {
    
    public init () {}

    public var body: some View {
        TabView {
            Comics.Views.SceneView()
            .environment(\.comicsEnv, .init(
                loadComic: ComicsServices.loadComic(id:),
                loadActualComic: ComicsServices.loadActualComic
            ))
            .tabItem {
                Image(systemName: "rectangle.on.rectangle.angled")
                Text("Comics")
            }
            // FavouritesSceneView(viewModel: favouritesViewModel)
            // .tabItem {
            //     Image(systemName: "heart.fill")
            //     Text("Favourites")
            // }
        }
        .font(.headline)
    }

}


#Preview("MainView") {
    MainView()
}
