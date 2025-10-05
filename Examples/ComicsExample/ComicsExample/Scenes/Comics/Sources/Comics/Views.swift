import Dispatch
import SwiftUI
import Oak

public enum Views {}

extension EnvironmentValues {
    @Entry public var comicsEnv: ComicsEnv = .init(
        loadComic: { _ in preconditionFailure("comicsEnv not setup") },
        loadActualComic: { preconditionFailure("comicsEnv not setup") }
    )
}

extension Views {
    
    public struct SceneView: View {
        @State private var state: Comics.Transducer.State = .init()
        @Environment(\.comicsEnv) var comicsEnv
        
        public init() {
            self.state = state
        }
        
        public var body: some View {
            NavigationView {
                TransducerView(
                    of: Comics.Transducer.self,
                    initialState: $state,
                    env: comicsEnv
                ) { state, input in
                    ContentView(
                        viewState: state.viewState,
                        input: input
                    )
                    .onAppear {
                        try? input.send(.start())
                    }
                }
            }
        }
    }
}

extension Views {
    
    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        return dateFormatter
    }()
    
}

extension Comic {
    var dateString: String {
        let dateString = self.date != nil ? Comics.Views.dateFormatter.string(from: date!) : nil ?? "release unknown"
        return dateString
    }
}

extension Views {

    struct ContentView: View {
        let viewState: Comics.Transducer.ViewState
        let input: Comics.Transducer.Proxy.Input

        @State var presentation: Comics.Transducer.Presentation? = nil
        @State var isAlertPresented: Bool = false

        var body: some View {
            VStack {
                switch viewState.content {
                case .present(let comic):
                    ComicView(comic: comic, input: input)
            
                case .absent(let noContent):
                    NoContentView(noContent: noContent, input: input)
                    
                case nil:
                    Text("ContentView: viewState uninitialized")
                        .foregroundStyle(Color.white)
                        .background(Color.red)
                }
            }
            .sheet(
                item: $presentation,
                onDismiss: { try? input.send(.didDismiss) }
            ) { presentation in
                Text("Sheet")
            }
            .onChange(of: viewState.presentation?.id, initial: true) { _, _ in
                self.presentation = viewState.presentation
            }
            .alert(
                "Error",
                isPresented: $isAlertPresented,
                presenting: viewState.failure,
                actions: { _ in
                    Button("OK") {
                        try? input.send(.didDismiss)
                    }
                }, message: { error in
                    AlertView(error: error)
                }
            )
            .onChange(of: viewState.isFailure, initial: true) { _, newValue in
                self.isAlertPresented = newValue
            }
            .navigationTitle("Actual Comic")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarView(input: input)
            }
        }
    }
    
    struct ToolbarView: View {
        let input: Comics.Transducer.Proxy.Input
        
        var body: some View {
            HStack {
                Button(action: { try? input.send(.intentShowRandomComic) }) {
                    Image(systemName: "sparkles.rectangle.stack")
                }.padding(4)
                Button(action: { try? input.send(.intentShowPreviousComic) }) {
                    Image(systemName: "arrow.left")
                }.padding(4)
                Button(action: { try? input.send(.intentShowNextComic) }) {
                    Image(systemName: "arrow.right")
                }.padding(4)
                Button(action: { try? input.send(.intentShowActualComic) }) {
                    Image(systemName: "arrow.right.to.line")
                }.padding(4)
            }
        }
    }
     
    struct AlertView: View {
        let message: String
        init(error: Swift.Error) {
            self.message = error.localizedDescription
        }
        var body: some View {
            Text(message)
        }
    }
     
    struct NoContentView: View {
        let noContent: States.NoContent
        let input: Comics.Transducer.Proxy.Input
        
        var body: some View {
            switch noContent {
            case .blank:
                Color.clear
            case .empty(title: let title, description: let description, action: _),
                    .error(title: let title, description: let description, action: _):
                ContentUnavailableView {
                    Label(title, systemImage: noContent.isError ? "photo.trianglebadge.exclamationmark" : "photo")
                        .tint(noContent.isError ? .red : .accentColor)
                } description: {
                    Text(description)
                } actions: {
                    // We ignore the given `action` parameter for now,
                    // until we enhanced the transsducer which requries
                    // to have the proxy's input in order to setup actions.
                    Button("Retry") {
                        try? input.send(.requestContent)
                    }
                }
            }
        }
    }

    struct ComicView: View {
        let comic: Comic
        let input: Comics.Transducer.Proxy.Input

        @State private var showAltText = false
        @GestureState private var isDetectingLongPress = false
        
        var body: some View {
            VStack {
                Text(comic.title)
                Text(comic.dateString)
                ZoomableImageView(url: comic.imageURL)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 1)
                        .onChanged({ value in
                            print("onEnded: \(value)")
                        })
                        .updating($isDetectingLongPress) { currentState, state, transaction in
                            print("updating: \(currentState)")
                            state = currentState
                        }
                        .onEnded { value in
                            print("onEnded: \(value)")
                            withAnimation {
                                self.showAltText = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3 + Double(comic.altText.count)/40) {
                                withAnimation {
                                    self.showAltText = false
                                }
                            }
                        }
                )
                .infoOverlay(isPresented: $showAltText, text: comic.altText)
                .padding(4)
                FavouriteCheckButton(isOn: comic.isFavourite) {
                    try? input.send(.intentToggleFavourite)
                }
            }
            .navigationTitle("Comic #\(comic.id)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
    
    struct FavouriteCheckButton: View {
        let isOn: Bool
        let action: () -> Void
        init(isOn: Bool, action: @escaping () -> Void) {
            self.isOn = isOn
            self.action = action
        }
        
        var body: some View {
            Button(action: action ) {
                Image(systemName: isOn ? "heart.fill": "heart")
            }
        }
    }
    
}


private extension View {
    
    @ViewBuilder
    func infoOverlay(isPresented: Binding<Bool>, text: String) -> some View {
        if isPresented.wrappedValue {
            ZStack {
                self
                Text(text)
                .font(.callout)
                .padding()
                .background(Color.yellow)
                .cornerRadius(16)
                .padding(16)
            }
        } else {
            self
        }
    }
}


#if DEBUG

// MARK: - Previews

#Preview("ComicView") {
    @Previewable @State var proxy: Comics.Transducer.Proxy = .init()

    Views.ComicView(
        comic: .init(
            id: 123,
            title: "A random image",
            date: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2078, month: 7, day: 12))!,
            imageURL: URL(
                string: "https://picsum.photos/200/300"
            )!,
            altText: "Alternate text",
            isFavourite: false
        ),
        input: proxy.input
    )
}

#Preview("ContentView") {
    
    @Previewable @State var comic: Comic = .init(
        id: 123,
        title: "A random image",
        date: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2078, month: 7, day: 12))!,
        imageURL: URL(
            string: "https://picsum.photos/200/300"
        )!,
        altText: "Alternate text",
        isFavourite: false
    )
    
    @Previewable @State var proxy: Comics.Transducer.Proxy = .init()
    
    Views.ContentView(
        viewState: .idle(content: .present(comic)),
        input: proxy.input
    )
}

#Preview("SceneView") {
    
    Views.SceneView()
        .environment(\.comicsEnv, .init(
            loadComic: { id in
                // Simulate a short delay as if fetching from the network
                try? await Task.sleep(nanoseconds: 100_000_000)
                return Comic(
                    id: id,
                    title: "Mocked Comic #\(id)",
                    date: Date(),
                    imageURL: URL(string: "https://picsum.photos/400/300?random=\(id)")!,
                    altText: "This is mocked alt text for comic #\(id).",
                    isFavourite: false
                )
            },
            loadActualComic: {
                // Simulate a short delay as if fetching the latest comic
                try? await Task.sleep(nanoseconds: 100_000_000)
                let id = 9999
                return Comic(
                    id: id,
                    title: "Mocked Actual Comic",
                    date: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2099, month: 2, day: 2))!,
                    imageURL: URL(string: "https://picsum.photos/400/300?random=\(id)")!,
                    altText: "This is mocked alt text for the actual comic.",
                    isFavourite: true
                )
            }
        ))
}
#endif

