#if false
import SwiftUI

extension Favourites.Views {
    public struct FavouritesSceneView: View {
        typealias Modal = ModalState<AlertState, SheetState, ActionSheetState, ProgressState>
        
        let viewState: Favourites.Transducers.ViewState
        let send: (Favourites.Transducers.Event) -> Void
        
        public init(
            viewState: Favourites.Transducers.ViewState,
            send: @escaping (Favourites.Transducers.Event) -> Void
        ) {
            self.viewState = viewState
            self.send = send
        }
        
        var body: some View {
            NavigationView {
                either(viewState.content, right: { state in
                    FavouritesContentView(
                        state: state,
                        onDeleteFavourite: { id in
                            send(.requestDeleteFavourite(id: id))
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
                .navigationTitle("My Favourites")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    HStack {
                        EmptyView()
                    }
                }
            }
        }
    }

    
    struct FavouritesContentView: View {
        let state: [Comics.Comic]
        let onDeleteFavourite: (String) -> Void
        
        init(state favourites: [Comics.Comic], onDeleteFavourite: @escaping (String) -> Void) {
            self.state = favourites
            self.onDeleteFavourite = onDeleteFavourite
        }
        
        var body: some View {
            VStack {
                FavouritesView(favourites: state)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
}

// MARK: - Previews

#Preview("FavouritesContentView") {
    @Previewable @State var favourites: [Comics.Comic] = Mocks.favourites

    Favourites.Views.FavouritesContentView(
        state: favourites,
        onDeleteFavourite: { _ in }
    )
}

#Preview("FavouritesSceneView") {
    @Previewable @State var viewState: Favourites.Transducers.ViewState = .init(
        content: .right(Mocks.favourites)
    )

    Favourites.Views.FavouritesSceneView(
        viewState: viewState,
        send: { _ in }
    )
}

#endif
