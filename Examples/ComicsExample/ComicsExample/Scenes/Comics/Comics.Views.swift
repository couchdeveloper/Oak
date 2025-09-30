import Dispatch
import SwiftUI
import Oak

extension Comics { enum Views {} }

extension Comics.Views {
    
    public struct SceneView: View {
        typealias Modal = ModalState<AlertState, SheetState, ActionSheetState, ProgressState>
        
        let viewState: Comics.Transducer.ViewState
        let send: (Comics.Transducer.Event) -> Void
        
        var body: some View {
            NavigationView {
                either(viewState.content, right: { state in
                    Comics.Views.ContentView(
                        comic: state,
                        onToggleFavourite: {
                            send(.intentToggleFavourite)
                        }
                    )
                }, left: { state in
                    NoContentView(state: state)
                        .onAppear {
                            send(.requestContent)
                        }
                })
                .background(Color.clear)
                .modal(viewState.modal, dismiss: { send(.didDismiss) } )
                .navigationBarTitle("Actual Comic", displayMode: .inline)
                .toolbar {
                    HStack {
                        Button(action: { send(.intentShowRandomComic) }) {
                            Image(systemName: "sparkles.rectangle.stack")
                        }.padding(4)
                        Button(action: { send(.intentShowPreviousComic) }) {
                            Image(systemName: "arrow.left")
                        }.padding(4)
                        Button(action: { send(.intentShowNextComic) }) {
                            Image(systemName: "arrow.right")
                        }.padding(4)
                        Button(action: { send(.intentShowActualComic) }) {
                            Image(systemName: "arrow.right.to.line")
                        }.padding(4)
                    }
                }
            }
        }
    }
}


extension Comics.Views {
    
    struct ContentView: View {
        let comic: Comics.Comic
        let onToggleFavourite: () -> Void
        
        init(comic: Comics.Comic, onToggleFavourite: @escaping () -> Void) {
            self.comic = comic
            self.onToggleFavourite = onToggleFavourite
        }
        
        var body: some View {
            VStack {
                ComicView(comic: comic)
                HStack {
                    FavouriteCheckButton(isOn: comic.isFavourite) {
                        self.onToggleFavourite()
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension Comics.Views {
    
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

// A View that renders a "Comic"
extension Comics.Views {
    
    struct ComicView: View {
        let comic: Comics.Comic
        
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
            }
            .padding(4)
            .navigationBarTitle("Comic #\(comic.id)")
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
    Comics.Views.ComicView(
        comic: .init(
            id: "123",
            title: "A random image",
            dateString: "Monday, 12.07.2078",
            imageURL: URL(
                string: "https://picsum.photos/200/300"
            )!,
            altText: "Alternate text",
            isFavourite: false
        )
    )
}

#Preview("ContentView") {
    
    @Previewable @State var comic: Comics.Comic = .init(
        id: "123",
        title: "A random image",
        dateString: "Monday, 12.07.2078",
        imageURL: URL(
            string: "https://picsum.photos/200/300"
        )!,
        altText: "Alternate text",
        isFavourite: false
    )
    
    Comics.Views.ContentView(
        comic: comic,
        onToggleFavourite: {
            print("onToggleFavourite tapped")
        }
    )
}

#Preview("SceneView") {
    
    @Previewable @State var viewState: Comics.Transducer.ViewState = .init(
        content: .left(.empty(
            title: "No content",
            description: "There's no comic to display."
        ))
    )
    
    Comics.Views.SceneView(
        viewState: viewState,
        send: { event in
            print("send event: \(event)")
        }
    )
}
#endif
