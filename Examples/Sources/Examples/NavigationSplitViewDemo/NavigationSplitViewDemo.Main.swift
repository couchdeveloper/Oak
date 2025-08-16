import SwiftUI
import Oak

// MARK: - View 


extension NavigationSplitViewDemo.Main.Views {
    
    struct ContentNavigationView: View {
        var body: some View {
            NavigationStack {
                MainDetailView()
            }
        }
    }
    

    struct MainDetailView: View {

        typealias List = NavigationSplitViewDemo.List
        typealias Detail = NavigationSplitViewDemo.Detail        
        typealias DetailCallback = Callback<String>

        @State private var listState: List.State = .start
        @State private var listProxy: List.Proxy = .init()

        let detailCallback: Callback<Detail.Output> = .init { output in
            switch output {
            case .loadSuccess(let itemId):
                // Handle successful loading of item
                print("Loaded item: \(itemId)")
            case .loadFailed(let error, let itemId):
                // Handle failed loading of item
                print("Failed to load item \(itemId): \(error)")
            case .message(let message):
                // Handle message from detail view
                print("Message from detail view: \(message)")
            case .none:
                break
            }
        }

        let listCallback: Callback<List.Output> = .init { output in
            switch output {
            case .itemSelected(let itemId):
                break
            case .none:
                break
            }
        }

        var body: some View {            
            NavigationSplitView {
                List.Views.ContentView(
                    state: $listState,
                    proxy: listProxy,
                    output: listCallback
                )
            } detail: {
                Detail.Views.ContentView(
                    itemId: listState.selectedItemId,
                    output: detailCallback
                )
            }
        }
    }
    
}
