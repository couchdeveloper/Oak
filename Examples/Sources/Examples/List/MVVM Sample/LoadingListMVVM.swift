import Foundation
import SwiftUI

// MARK: - Environment Definition
extension EnvironmentValues {
    @Entry var dataServiceMVVM: (String) async throws -> LoadingListMVVM.Models.DataModel = { _ in
        throw NSError(
            domain: "DataService", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Data service not configured"])
    }
}

// MARK: - UseCase/Demo "LoadingListMVVM" TOC
enum LoadingListMVVM {
    enum ViewModels {}
    enum Views {}
    enum Models {}
}

// MARK: - Data Models
extension LoadingListMVVM.Models {
    struct DataModel {
        let items: [String]
    }

    struct EmptyStateModel {
        let title: String
        let description: String
        let actionTitle: String
    }

    struct ErrorModel {
        let title: String
        let message: String
    }
}

// MARK: - Simple ViewModel without reactive cycles
extension LoadingListMVVM.ViewModels {
    @MainActor
    class LoadingListViewModel: ObservableObject {
        // Core state - only what's absolutely necessary
        @Published var data: LoadingListMVVM.Models.DataModel?
        @Published var isLoading = false
        @Published var error: LoadingListMVVM.Models.ErrorModel?

        // Private properties
        private var dataService: (String) async throws -> LoadingListMVVM.Models.DataModel = { _ in
            throw NSError(
                domain: "DataService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Data service not configured"])
        }
        private var loadingTask: Task<Void, Never>?

        // Computed properties (no @Published to avoid cycles)
        var isEmpty: Bool {
            return data == nil && !isLoading && error == nil
        }

        var emptyState: LoadingListMVVM.Models.EmptyStateModel {
            if let error = error {
                return LoadingListMVVM.Models.EmptyStateModel(
                    title: "Loading failed",
                    description: error.message,
                    actionTitle: "Try again"
                )
            } else {
                return LoadingListMVVM.Models.EmptyStateModel(
                    title: "Info",
                    description: "No data available. Press Start to load items.",
                    actionTitle: "Start"
                )
            }
        }

        // MARK: - Initialization
        func configure(
            dataService: @escaping (String) async throws -> LoadingListMVVM.Models.DataModel
        ) {
            self.dataService = dataService
        }

        // MARK: - User Actions
        func startLoading(with parameter: String) {
            // Cancel existing loading task
            loadingTask?.cancel()

            // Clear previous state
            error = nil

            // Start loading
            isLoading = true

            loadingTask = Task { @MainActor in
                do {
                    let result = try await self.dataService(parameter)

                    // Check if task was cancelled
                    if Task.isCancelled {
                        return
                    }

                    // Update UI with success
                    self.data = result
                    self.isLoading = false

                } catch {
                    // Check if task was cancelled
                    if Task.isCancelled {
                        return
                    }

                    // Handle error
                    self.handleError(error)
                }
            }
        }

        func cancelLoading() {
            loadingTask?.cancel()
            loadingTask = nil
            isLoading = false
        }

        func dismissError() {
            error = nil
        }

        func retry() {
            // Will be handled by the view
        }

        // MARK: - Private Methods
        private func handleError(_ error: Error) {
            self.error = LoadingListMVVM.Models.ErrorModel(
                title: "Error",
                message: error.localizedDescription
            )
            self.isLoading = false
            self.data = nil
        }

        // MARK: - Lifecycle
        deinit {
            loadingTask?.cancel()
        }
    }
}

// MARK: - Views with separate sheet management
extension LoadingListMVVM.Views {

    struct MainView: View {
        @StateObject private var viewModel = LoadingListMVVM.ViewModels.LoadingListViewModel()
        @Environment(\.dataServiceMVVM) private var dataService

        var body: some View {
            ContentView(viewModel: viewModel)
                .onAppear {
                    viewModel.configure(dataService: dataService)
                }
        }
    }

    struct ContentView: View {
        @ObservedObject var viewModel: LoadingListMVVM.ViewModels.LoadingListViewModel
        @State private var showSheet = false
        @State private var inputText = "sample"

        var body: some View {
            NavigationStack {
                ZStack {
                    // Main content based on state
                    if viewModel.isEmpty {
                        EmptyStateView(
                            model: viewModel.emptyState,
                            onAction: {
                                inputText = "sample"
                                showSheet = true
                            }
                        )
                    } else if let data = viewModel.data {
                        DataListView(data: data)
                    }

                    // Loading overlay
                    if viewModel.isLoading {
                        LoadingOverlay(onCancel: viewModel.cancelLoading)
                    }
                }
                .sheet(isPresented: $showSheet) {
                    InputSheetView(
                        inputText: $inputText,
                        onCommit: { parameter in
                            showSheet = false
                            viewModel.startLoading(with: parameter)
                        },
                        onCancel: {
                            showSheet = false
                        }
                    )
                }
                .alert(
                    viewModel.error?.title ?? "Error",
                    isPresented: .constant(viewModel.error != nil)
                ) {
                    Button("OK") {
                        viewModel.dismissError()
                    }
                } message: {
                    Text(viewModel.error?.message ?? "Unknown error")
                }
                .navigationTitle("Loading List Demo (MVVM)")
            }
        }
    }

    struct EmptyStateView: View {
        let model: LoadingListMVVM.Models.EmptyStateModel
        let onAction: () -> Void

        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                Text(model.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(model.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(model.actionTitle) {
                    onAction()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    struct DataListView: View {
        let data: LoadingListMVVM.Models.DataModel

        var body: some View {
            List(data.items, id: \.self) { item in
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text(item)
                }
                .padding(.vertical, 4)
            }
        }
    }

    struct LoadingOverlay: View {
        let onCancel: () -> Void

        var body: some View {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text("Loading...")
                        .font(.headline)

                    Text("Fetching data from service")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(30)
                .background(.regularMaterial)
                .cornerRadius(12)
                .shadow(radius: 10)
            }
        }
    }

    struct InputSheetView: View {
        @Binding var inputText: String
        let onCommit: (String) -> Void
        let onCancel: () -> Void

        var body: some View {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Enter a parameter to load data:")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()

                    TextField("Enter parameter", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    Spacer()
                }
                .navigationTitle("Load Data")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            onCancel()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Load") {
                            onCommit(inputText)
                        }
                        .disabled(inputText.isEmpty)
                    }
                }
            }
        }
    }
}

// MARK: - Preview Support
extension LoadingListMVVM.Views {

    /// Fake service function suitable for previews and testing
    static func previewDataService() -> (String) async throws -> LoadingListMVVM.Models.DataModel {
        return { parameter in
            // Simulate network delay
            try await Task.sleep(nanoseconds: UInt64.random(in: 500_000_000 ... 2_000_000_000))  // 0.5-2 seconds

            // Simulate occasional errors (30% chance)
            if Int.random(in: 1 ... 10) <= 3 {
                throw NSError(
                    domain: "PreviewDataService",
                    code: 500,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Simulated network error for parameter: \(parameter)"
                    ]
                )
            }

            // Generate realistic mock data based on parameter
            let baseItems = [
                "📄 Document Alpha",
                "📊 Report Beta",
                "📈 Analysis Gamma",
                "📋 Summary Delta",
                "🔍 Research Epsilon",
                "💡 Insights Zeta",
                "📝 Notes Eta",
                "🎯 Goals Theta"
            ]

            let filteredItems = baseItems.filter { item in
                parameter.isEmpty || item.localizedCaseInsensitiveContains(parameter)
            }

            let finalItems =
                filteredItems.isEmpty
                ? [
                    "No results for '\(parameter)'",
                    "Try a different search term",
                    "Or browse all available items"
                ] : Array(filteredItems.shuffled().prefix(Int.random(in: 2 ... 6)))

            return LoadingListMVVM.Models.DataModel(
                items: finalItems + [
                    "Generated at: \(Date().formatted(date: .abbreviated, time: .shortened))"
                ]
            )
        }
    }
}

// MARK: - SwiftUI Previews
#Preview("LoadingList MVVM Demo") {
    LoadingListMVVM.Views.MainView()
        .environment(\.dataServiceMVVM, LoadingListMVVM.Views.previewDataService())
}

#Preview("LoadingList MVVM with Error Service") {
    LoadingListMVVM.Views.MainView()
        .environment(\.dataServiceMVVM) { _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)
            throw NSError(
                domain: "Preview", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Preview error - service unavailable"])
        }
}
