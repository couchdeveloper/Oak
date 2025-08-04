import SwiftUI

/// Demo app showing LoadingList usage
struct LoadingListDemoApp: App {
    var body: some Scene {
        WindowGroup {
            LoadingList.Views.MainView()
                .environment(\.dataService, LoadingList.Views.previewDataService())
        }
    }
}

/// Alternative usage with custom service
struct CustomServiceExample: View {
    var body: some View {
        LoadingList.Views.MainView()
            .environment(\.dataService) { parameter in
                // Custom service implementation
                try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                
                // Real API call would go here
                return LoadingList.Transducer.Data(
                    items: [
                        "Custom Item A for \(parameter)",
                        "Custom Item B for \(parameter)",
                        "Custom Item C for \(parameter)"
                    ]
                )
            }
    }
}

#Preview("LoadingList Demo App") {
    LoadingList.Views.MainView()
        .environment(\.dataService, LoadingList.Views.previewDataService())
        .frame(width: 400, height: 600)
}

#Preview("Custom Service Example") {
    CustomServiceExample()
        .frame(width: 400, height: 600)
}
