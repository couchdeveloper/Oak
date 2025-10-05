import SwiftUI
import Main

@main
struct ViewAppApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }

    init() {
        // setUpNavigationBarAppearance()
        // UITableView.appearance().backgroundColor = .clear // tableview background
        // UITableViewCell.appearance().backgroundColor = .clear // cell background
    }

    // private func setUpNavigationBarAppearance() {
    //     let appearance = UINavigationBarAppearance()
    //     appearance.configureWithOpaqueBackground()
    //     let textAttrs: [NSAttributedString.Key: Any] = [
    //         .foregroundColor: UIColor.black,
    //         .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .medium)
    //     ]
    //     appearance.largeTitleTextAttributes = textAttrs
    //     UINavigationBar.appearance().scrollEdgeAppearance = appearance
    //     UINavigationBar.appearance().compactAppearance = appearance
    //     UINavigationBar.appearance().standardAppearance = appearance
    // }

}
