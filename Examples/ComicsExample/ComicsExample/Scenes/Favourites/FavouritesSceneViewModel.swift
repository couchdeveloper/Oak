#if false
import Combine
import Dispatch
import Foundation

extension Favourites { enum Transducers {} }
    
extension Favourites.Transducers {
    
    typealias Modal = ModalState<AlertState, SheetState, ActionSheetState, ProgressState>
    typealias ViewState = ComicsExample.ViewState<Either<[Comics.Comic], NoContent>, Modal>
    
    enum Event {
        // Intents / Requests
        case requestCancel
        case requestContent
        case requestDeleteFavourite(id: String)
        
        // Facts
        case didDismiss
        case didMutateOrigin
        case didCompleteLoading(Result<[Comics.Comic], Swift.Error>)
    }
    
    struct State {
        enum Mutation: Equatable {
            case loadingContent
            case deletingElements(set: Set<Comics.Comic.ID>)
        }
        
        enum State: Equatable {
            case idle
            case mutating(Mutation)
        }
        
        var viewState = ViewState(content: .left(.blank))
        var status: State = .idle
    }
    
    static func update(_ state: inout State, event: Event) {
        switch event {
        case .requestCancel:
            state = requestCancel(state)
            
        case .requestContent:
            state = requestContent(state)
            
        case .requestDeleteFavourite(id: let id):
            state = requestDeleteFavourite(id: id, state: state)
            
        case .didDismiss:
            state = didDismiss(state)
            
        case .didCompleteLoading(let result):
            state = didCompleteLoading(with: result, state: state)
            
        case .didMutateOrigin:
            state = didMutateOrigin(state)
        }
    }
    
    private static func requestCancel(_ state: State) -> State {
        // not yet implemented
        return state
    }
}

extension Favourites.Transducers {

    private static func requestContent(_ state: State) -> State {
        guard state.viewState.content.right == nil else {
            // Note: this should not happen! If a view already shows its content
            // it never should request it again or allows input which creates
            // `requestContent` events.
            // Note, that this event is distinct from explicit "refresh" or
            // "update" requests which may be allowed when content is shown.
            print("WARNING: request content denied: requested content is already present")
            return state
        }

        if let modal = state.viewState.modal, case .alert = modal {
            // CAUTION: this must not happen! If a view is in a modal.alert state
            // it never should request content itself or allow input which
            // creates `requestContent` events. The alert content is assumed to
            // refer to the current content - thus, this content must not change
            // when there is an alert telling the user there is something wrong
            // with _this_ content.
            print("ERROR: request content denied: view is in modal state")
            return state
        }

        guard state.status == .idle else {
            print("WARNING: requestContent denied: view model not in idle state")
            return state
        }

        var state = state
        state.viewState.modal = .progress(.init(label: "loading..."))
        state.status = .mutating(.loadingContent)
        return state
    }

    private static func requestDeleteFavourite(id: String, state: State) -> State {
        guard state.status == .idle else {
            print("WARNING: requestDeleteFavourite denied: view model not in idle state")
            return state
        }
        var state = state
        let elementsToDelete = Set.init([id])
        state.viewState.modal = .progress(.init(label: "deleting favourites..."))
        state.status = .mutating(.deletingElements(set: elementsToDelete))
        return state
    }

    private static func didDismiss(_ state: State) -> State {
        var state = state
        state.viewState.modal = nil
        return state
    }

    private static func didCompleteLoading(with result: Result<[Comics.Comic], Swift.Error>, state: State) -> State {
        var state = state
        state.status = .idle
        switch result {
        case .success(let comics):
            if comics.count > 0 {
                state.viewState = ViewState(content: .right(comics))
            } else {
                state.viewState = ViewState(content: .left(.empty(title: "Favourites", description: "The list is empty because you have no favourites defined.")))
            }

        case .failure(let error):
            let alert = AlertState(title: "Error", message: String(describing: error))
            state.viewState.modal = .alert(alert)
        }
        return state
    }

    private static func didMutateOrigin(_ state: State) -> State {
        var state = state
        state.status = .mutating(.loadingContent)
        return state
    }

}


#if false
enum FavouritsSceneEvent {
    // Intents / Requests
    case requestCancel
    case requestContent
    case requestDeleteFavourite(id: String)

    // Facts
    case didDismiss
    case didMutateOrigin
    case didCompleteLoading(Result<[Comics.Comic], Swift.Error>)
}

class FavouritesSceneViewModel: ObservableObject, ViewModel {
    typealias Event = FavouritsSceneEvent
    typealias Modal = ModalState<AlertState, SheetState, ActionSheetState, ProgressState>
    typealias ViewState = MVVM.ViewState<Either<[Comic], NoContent>, Modal>

    @Published var viewState: ViewState = ViewState(content: .left(.blank))

    init(favouritesStore: AnyFavouritesStore<Comic, UIImage>) {
        self.state = State()
        self.favouritesStore = favouritesStore

        Publishers.system(
            initial: state,
            reduce: Self.reduce,
            feedbacks: [
                userInput(input: input.eraseToAnyPublisher()),
                whenLoadingContent(),
                whenDeletingElements()
            ],
            scheduler: RunLoop.main
        )
        .assign(to: \.state, on: self)
        .store(in: &cancellables)
    }

    private struct State {
        enum Mutation: Equatable {
            case loadingContent
            case deletingElements(set: Set<Comic.ID>)
        }

        enum State: Equatable {
            case idle
            case mutating(Mutation)
        }

        var viewState: ViewState = ViewState(content: .left(.blank))
        var status: State = .idle
    }

    private var state: State {
        willSet {
            //dump(state, name: "old")
            //dump(newValue, name: "new")
            self.viewState = newValue.viewState
        }
    }

    private var cancellables: Set<AnyCancellable> = []
    private let input = PassthroughSubject<Event, Never>()
    private let favouritesStore: AnyFavouritesStore<Comic, UIImage>

    func send(_ event: Event) {
        NSLog("*** User command: \(event)")
        input.send(event)
    }

    func dismiss() {
        send(.didDismiss)
    }


    // MARK: - Reducer

    private static func reduce(_ state: State, _ event: Event) -> State {
        let output: State
        switch event {
        case .requestCancel:
            output = requestCancel(state)

        case .requestContent:
            output = requestContent(state)

        case .requestDeleteFavourite(id: let id):
            output = requestDeleteFavourite(id: id, state: state)

        case .didDismiss:
            output = didDismiss(state)

        case .didCompleteLoading(let result):
            output = didCompleteLoading(with: result, state: state)

        case .didMutateOrigin:
            output = didMutateOrigin(state)
        }

        print("*** reduce(\(state.status), \(event)) -> \(output.status)")
        return output
    }
}
#endif

#if false
// MARK: - Feedbacks
extension FavouritesSceneViewModel {

    // MARK: Feedback UserInput

    private func userInput(input: AnyPublisher<Event, Never>) -> Feedback<State, Event> {
        Feedback.compact(name: "Input") { (state: State) -> AnyPublisher<Event, Never> in
            input
        }
    }

    // MARK: Feedback LoadContent

    // If state equals `loadingContent` start a loading operation.
    // Note that any received stimuli will cancel a pending load operation.
    //
    // The effect retrieves the ids from the favourite store, then fetches all
    // comics from the API and issues an Event `didCompleteLoading` with the result.
    private func whenLoadingContent() -> Feedback<State, Event> {
        Feedback.compact(name: "LoadContent") { (state: State) -> AnyPublisher<Event, Never> in
            guard case .mutating(let what) = state.status, case .loadingContent = what else {
                return Empty().eraseToAnyPublisher()
            }

            func fetchComics(ids: Set<String>) -> AnyPublisher<[Comic], ComicAPI.Error> {
                ComicAPI.comics(ids: ids.map { id in
                    Int(id)!
                })
                .map { dtoComics in
                    dtoComics.map { Comic(dtoComic: $0, isFavourite: true) }
                }.eraseToAnyPublisher()
            }

            return self.favouritesStore.all()
                .flatMap { ids in
                    fetchComics(ids: ids)
                    .map { comics in
                        Event.didCompleteLoading(.success(comics))
                    }
                    // we need to map the error to the same type as its upstream
                    // publisher (`favouritesStore.all()`), otherwise `catch` get
                    // stuck.
                    .mapError { FavouritesStore.Error.internal($0) }
                }
                .catch { error in
                    Just(Event.didCompleteLoading(.failure(error)))
                }
                .eraseToAnyPublisher()
        }
    }


    // MARK: Feedback DeleteElements

    private func whenDeletingElements() -> Feedback<State, Event> {
        Feedback.compact(name: "DeleteElements") { (state: State) -> AnyPublisher<Event, Never> in
            guard case .mutating(let what) = state.status, case .deletingElements(let elementsToDelete) = what else {
                return Empty().eraseToAnyPublisher()
            }
            return elementsToDelete.publisher
            .flatMap(self.favouritesStore.unsetFavourite)
            .collect()
            .map { _ in
                Event.didMutateOrigin
            }
            .replaceError(with: Event.didMutateOrigin) // TODO: handle errors more gracefully
            .eraseToAnyPublisher()
        }
    }

}
#endif
#endif
