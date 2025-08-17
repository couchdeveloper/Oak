import Oak
import SwiftUI

// MARK: - Environment Definition
extension EnvironmentValues {
    @Entry var dataService: (String) async throws -> LoadingList.Transducer.Data = { _ in
        throw NSError(domain: "DataService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data service not configured"])
    }
}

// MARK: UseCase/Demo "LoadingList" TOC
enum LoadingList {
    enum Transducer {}
    enum Views {}
}

// MARK: Transducer
extension LoadingList.Transducer: EffectTransducer {
    struct Env {
        let service: (String) async throws -> Data
        let input: Input
        
        init(service: @escaping (String) async throws -> Data, input: Input) {
            self.service = service
            self.input = input
        }
    }
    
    struct Sheet: Identifiable {
        var id: String = ""
        let title: String
        let description: String
        let `default`: String
        let commit: (String) -> Void
        let cancel: () -> Void
    }
    
    struct Data {
        let items: [String]
    }
    
    typealias State = Utilities.State<Data, Sheet>

    enum Event {
        // Events sent from views
        case viewOnAppear
        case viewSheetDidDismiss

        // Events activated from the user
        // case intentRefresh
        case intentShowSheet
        case intentSheetCommit(String)
        case intentSheetCancel
        case intentAlertConfirm

        // Events sent from the service
        case serviceError(Swift.Error)
        case serviceLoaded(Data)
        
        // Events sent from setup effects
        case configureContext(State.Context)

        // Events sent from modal actions
        case cancelLoading
    }
    
    // MARK: - Effects Implementation

    /// This effect "imports" the context from the environment into the transducer.
    /// The context contains everything the actor knows about that the update function needs.
    static func configureContextEffect() -> Self.Effect {
        Effect(isolatedAction: { env, isolated in
            return .configureContext(State.Context(input: env.input))
        })
    }

    static func serviceLoadEffect(parameter: String) -> Self.Effect {
        Effect(isolatedOperation: { env, input, systemActor in
            do {
                let data = try await env.service(parameter)
                try input.send(.serviceLoaded(data))
            } catch {
                try input.send(.serviceError(error))
            }
        })
    }

    public static func update(_ state: inout State, event: Event) -> Self.Effect? {
        switch (state, event) {
        // Initial app state - first import the context from environment
        case (.start, .viewOnAppear):
            return configureContextEffect()
            
        // Context received - now configure empty state and transition to idle in one step
        case (.start, .configureContext(let context)):
            let actionClosure: @Sendable () -> Void = {
                try? context.input.send(.intentShowSheet)
            }
            let emptyState = State.Empty(
                title: "Info",
                description: "No data available. Press Start to load items.",
                actions: [
                    .init(id: "start", title: "Start", action: actionClosure)
                ]
            )
            state = .idle(.empty(emptyState), context)
            return nil
            
        // User wants to start loading data
        case (.idle(.empty(_), let context), .intentShowSheet):
            let sheet = Sheet(
                title: "Load Data", 
                description: "Enter a parameter to load data:", 
                default: "sample",
                commit: { parameter in
                    try? context.input.send(.intentSheetCommit(parameter))
                },
                cancel: {
                    try? context.input.send(.intentSheetCancel)
                }
            )
            state = .modal(state.content, .sheet(sheet), context)
            return nil
            
        // User confirms input in sheet
        case (.modal(let content, .sheet(_), let context), .intentSheetCommit(let parameter)):
            // Create loading state with cancel action using stored input
            let cancelAction = State.Action(
                id: "cancel", 
                title: "Cancel",
                action: { try? context.input.send(.cancelLoading) }
            )
            
            state = .modal(content, .loading(
                State.Loading(
                    title: "Loading...", 
                    description: "Fetching data from service", 
                    cancelAction: cancelAction
                )
            ), context)
            return serviceLoadEffect(parameter: parameter)
            
        // User cancels sheet
        case (.modal(let content, .sheet(_), let context), .intentSheetCancel):
            state = .idle(content, context)
            return nil
            
        // Sheet dismissed (programmatically)
        case (.modal(let content, .sheet(_), let context), .viewSheetDidDismiss):
            state = .idle(content, context)
            return nil
            
        // Service successfully loads data
        case (.modal(_, .loading(_), let context), .serviceLoaded(let data)):
            state = .idle(.data(data), context)
            return nil
            
        // Service encounters error
        case (.modal(_, .loading(_), let context), .serviceError(let error)):
            // Setup Alert
            let confirmAction = State.Action(
                id: "OK",
                title: "OK",
                action: { try? context.input.send(.intentAlertConfirm) }
            )
            
            state = .modal(.empty(State.Empty(
                title: "Error", 
                description: "Failed to load data.",
                actions: [confirmAction]
            )), .error(error), context)
            return nil
            
        // User dismisses error alert
        case (.modal(_, .error(let error), let context), .intentAlertConfirm):
            let actionClosure: @Sendable () -> Void = {
                try? context.input.send(.intentShowSheet)
            }
            let emptyState = State.Empty(
                title: "Loading failed",
                description: error.localizedDescription,
                actions: [
                    .init(id: "Try again", title: "Try again", action: actionClosure)
                ]
            )
            state = .idle(.empty(emptyState), context)
            return nil
            
        // // User wants to refresh when data is already loaded
        // case (.idle(.data(let data), let context), .intentRefresh):
        //     let sheet = Sheet(
        //         title: "Load Data",
        //         description: "Enter a parameter to load data:",
        //         default: "sample",
        //         commit: { parameter in
        //             try? context.input.send(.intentSheetCommit(parameter))
        //         },
        //         cancel: {
        //             try? context.input.send(.intentSheetCancel)
        //         }
        //     )
        //     state = .modal(.data(data), .sheet(sheet), context)
        //     return nil
            
        // Handle loading cancellation
        case (.modal(let content, .loading(_), let context), .cancelLoading):
            state = .idle(content, context)
            return nil
            
        // Default case - no state change
        default:
            return nil
        }
    }
}

// MARK: - Utilities

enum Utilities {

    // A Reusable State for "loading resources" scenarios
    public enum State<Data, Sheet>: NonTerminal {
        case start  // Initial state - equivalent to .idle(.empty(nil))
        case idle(Content, Context)  // Context contains actor components (always present)
        case modal(Content, Modal, Context)  // Context always present in operational states

        struct Empty {
            let title: String
            let description: String
            let actions: [Action]
        }

        struct Action {
            let id: String
            let title: String
            let action: () -> Void
        }

        struct Loading {
            let title: String
            let description: String
            let cancelAction: Action?
        }
        
        /// Context contains actor components accessible to the update function
        struct Context {
            let input: LoadingList.Transducer.Input
        }

        enum Content {
            case empty(Empty?)  // nil = unconfigured, needs setup
            case data(Data)
        }

        enum Modal {
            case loading(Loading?)  // nil = unconfigured, needs setup
            case error(Error)
            case sheet(Sheet?)      // nil = unconfigured, needs setup

            var isLoading: Bool {
                switch self {
                case .loading:
                    return true
                default:
                    return false
                }
            }
        }

        var isLoading: Bool {
            switch self {
            case .modal(_, let modal, _):
                return modal.isLoading
            case .idle, .start:
                return false
            }
        }

        var isEmpty: Bool {
            switch self {
            case .idle(let content, _):
                switch content {
                case .empty:
                    return true
                default:
                    return false
                }
            case .start:
                return true
            case .modal:
                return false
            }
        }

        var error: Error? {
            switch self {
            case .modal(_, let modal, _):
                if case .error(let error) = modal {
                    return error
                }
                return nil
            case .idle, .start:
                return nil
            }
        }

        var isError: Bool {
            return error != nil
        }

        var sheet: Sheet? {
            switch self {
            case .modal(_, let modal, _):
                if case .sheet(let sheet) = modal {
                    return sheet  // Can be nil if unconfigured
                }
                return nil
            case .idle, .start:
                return nil
            }
        }
        
        var isSheetConfigured: Bool {
            return sheet != nil
        }
        
        var loading: Loading? {
            switch self {
            case .modal(_, let modal, _):
                if case .loading(let loading) = modal {
                    return loading  // Can be nil if unconfigured
                }
                return nil
            case .idle, .start:
                return nil
            }
        }
        
        var isLoadingConfigured: Bool {
            return loading != nil
        }
        
        var emptyContent: Empty? {
            switch self {
            case .idle(let content, _):
                if case .empty(let empty) = content {
                    return empty  // Can be nil if unconfigured
                }
                return nil
            case .modal(let content, _, _):
                if case .empty(let empty) = content {
                    return empty  // Can be nil if unconfigured
                }
                return nil
            case .start:
                return nil  // Start state has no configured empty content
            }
        }
        
        var isEmptyConfigured: Bool {
            return emptyContent != nil
        }
        
        var context: Context? {
            switch self {
            case .idle(_, let context):
                return context
            case .modal(_, _, let context):
                return context
            case .start:
                return nil
            }
        }
        
        /// Context when in operational states (guaranteed to be non-nil)
        var operationalContext: Context? {
            switch self {
            case .idle(_, let context), .modal(_, _, let context):
                return context
            case .start:
                return nil
            }
        }
        
        var content: Content {
            switch self {
            case .idle(let content, _):
                return content
            case .modal(let content, _, _):
                return content
            case .start:
                return .empty(nil)  // Start state maps to unconfigured empty content
            }
        }
    }

}

// MARK: - Views

extension LoadingList.Views {
    
    struct MainView: View {
        @State private var proxy = LoadingList.Transducer.Proxy()
        @State private var state: LoadingList.Transducer.State = .start
        @Environment(\.dataService) private var dataService
        
        var body: some View {
            TransducerView(
                of: LoadingList.Transducer.self,
                initialState: $state,
                proxy: proxy,
                env: LoadingList.Transducer.Env(
                    service: dataService,
                    input: proxy.input
                ),
                completion: nil
            ) { state, input in
                ContentView(state: state, input: input)
            }
            .id(proxy.id)
            Button("Reset Demo") {
                proxy = .init()
            }
        }
    }
    
    struct ContentView: View {
        let state: LoadingList.Transducer.State
        let input: LoadingList.Transducer.Input
        
        var body: some View {
            NavigationStack {
                ZStack {
                    // Main content based on state
                    switch state.content {
                    case .empty(let empty):
                        EmptyStateView(empty: empty)
                    case .data(let data):
                        DataListView(data: data, input: input)
                    }
                    
                    // Modal overlays
                    if let loading = state.loading {
                        LoadingOverlay(loading: loading)
                    }
                }
                .sheet(item: .constant(state.sheet), onDismiss: {
                    print("sheet dismissed")
                }, content: { sheet in
                    InputSheetView(sheet: sheet)
                })
                .alert("Error", isPresented: .constant(state.isError)) {
                    Button("OK") {
                        try? input.send(.intentAlertConfirm)
                    }
                } message: {
                    Text(state.error?.localizedDescription ?? "Unknown error")
                }
                .navigationTitle("Loading List Demo")
                .onAppear {
                    try? input.send(.viewOnAppear)
                }
            }
        }
    }
    
    struct EmptyStateView: View {
        let empty: LoadingList.Transducer.State.Empty?
        
        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                if let empty = empty {
                    Text(empty.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(empty.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 12) {
                        ForEach(empty.actions.indices, id: \.self) { index in
                            let action = empty.actions[index]
                            Button(action.title) {
                                action.action()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    Text("Configuring...")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
    
    struct DataListView: View {
        let data: LoadingList.Transducer.Data
        let input: LoadingList.Transducer.Input
        
        var body: some View {
            List(data.items, id: \.self) { item in
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text(item)
                }
                .padding(.vertical, 4)
            }
            //.refreshable {
            //    // Not yet implemented properly.
            //    try? input.send(.intentRefresh)
            //}
        }
    }
    
    struct LoadingOverlay: View {
        let loading: LoadingList.Transducer.State.Loading
        
        var body: some View {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text(loading.title)
                        .font(.headline)
                    
                    Text(loading.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if let cancelAction = loading.cancelAction {
                        Button(cancelAction.title) {
                            cancelAction.action()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(30)
                .background(.regularMaterial)
                .cornerRadius(12)
                .shadow(radius: 10)
            }
        }
    }
    
    struct InputSheetView: View {
        let sheet: LoadingList.Transducer.Sheet
        @State private var inputText: String = ""
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 20) {
                    Text(sheet.description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    TextField("Enter parameter", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationTitle(sheet.title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            sheet.cancel()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Load") {
                            sheet.commit(inputText)
                        }
                        .disabled(inputText.isEmpty)
                    }
                }
                .onAppear {
                    inputText = sheet.default
                }
            }
        }
    }
}

// MARK: - ViewModels
// No ViewModels

// MARK: - Usage Example
extension LoadingList.Views {
    
    /// Example of how to use MainView with a configured data service
    @MainActor
    static func exampleUsage() -> some View {
        MainView()
            .environment(\.dataService) { parameter in
                // Simulate async data loading
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                
                // Return mock data based on parameter
                return LoadingList.Transducer.Data(
                    items: [
                        "Item 1 for \(parameter)",
                        "Item 2 for \(parameter)",
                        "Item 3 for \(parameter)",
                        "Generated data: \(Date().formatted())"
                    ]
                )
            }
    }
}

// MARK: - Preview Support
extension LoadingList.Views {
    
    /// Fake service function suitable for previews and testing
    @MainActor
    static func previewDataService() -> (String) async throws -> LoadingList.Transducer.Data {
        return { parameter in
            // Simulate network delay
            try await Task.sleep(nanoseconds: UInt64.random(in: 500_000_000...5_000_000_000)) // 0.5-5 seconds
            
            // Simulate occasional errors (50% chance)
            if Int.random(in: 1 ... 2) == 1 {
                throw NSError(
                    domain: "PreviewDataService", 
                    code: 500, 
                    userInfo: [NSLocalizedDescriptionKey: "Simulated network error for parameter: \(parameter)"]
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
            
            let finalItems = filteredItems.isEmpty ? [
                "No results for '\(parameter)'",
                "Try a different search term",
                "Or browse all available items"
            ] : Array(filteredItems.shuffled().prefix(Int.random(in: 2...6)))
            
            return LoadingList.Transducer.Data(
                items: finalItems + ["Generated at: \(Date().formatted(date: .abbreviated, time: .shortened))"]
            )
        }
    }
}

// MARK: - SwiftUI Previews
#Preview("LoadingList Demo") {
    LoadingList.Views.MainView()
        .environment(\.dataService, LoadingList.Views.previewDataService())
}

#Preview("LoadingList with Error Service") {
    LoadingList.Views.MainView()
        .environment(\.dataService) { _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)
            throw NSError(domain: "Preview", code: 404, userInfo: [NSLocalizedDescriptionKey: "Preview error - service unavailable"])
        }
}
