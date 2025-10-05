#if false
import Dispatch
import Foundation
import class UIKit.UIImage


extension Comics.Transducer {
    
    static func output(state: State, event: Event) -> ViewState {
        
    }

    private static func didDismiss(_ state: inout State) -> ViewState {
        var state = state
        state.viewState.modal = nil
        return state
    }

    private static func requestCancel(_ state: inout State) -> ViewState {
        // not yet implemented
        return state
    }

    private static func requestToggleFavourite(_ state: inout State) -> ViewState {
        var state = state
        state.status = .togglingFavourite
        return state
    }

    private static func didToggleFavourite(_ state: inout State, isFavourite: Bool, id: Int) -> ViewState {
        var state = state
        guard var comic = state.viewState.content.right, let currentId = Int(comic.id), id == currentId else {
            return state
        }
        comic.isFavourite = isFavourite
        state.status = .idle
        state.viewState.content = .right(comic)
        return state
    }

    private static func showActualComic(_ state: inout State) -> ViewState {
        var state = state
        state.index = nil
        return requestContent(state)
    }

    private static func requestShowNextComic(_ state: State) -> State {
        // Try load the next of the _current_ comic if any, otherwise load the
        // actual comic.
        var state = state
        if let comic = state.viewState.content.right, let currentIndex = Int(comic.id) {
            state.index = currentIndex + 1
        }
        return requestContent(state)
    }

    private static func requestShowPreviousComic(_ state: State) -> State {
        // Try load the previous of the _current_ comic if any, otherwise load the
        // actual comic.
        var state = state
        if let comic = state.viewState.content.right, let currentIndex = Int(comic.id) {
            state.index = max(state.firstIndex, currentIndex - 1)
        }
        return requestContent(state)
    }

    private static func requestShowRandomComic(_ state: State) -> State {
        var state = state
        state.index = Int.random(in: state.firstIndex...state.lastIndex)
        return requestContent(state)
    }

    private static func requestSaveToImageStore(_ state: State) -> State {
        var state = state
        state.status = .requestingSaveToImageStore
        return state
    }

    private static func requestContent(_ state: State) -> State {
        if let currentIndexString = state.viewState.content.right?.id,
           let currentIndex = Int(currentIndexString), currentIndex == state.index {
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

        guard state.status != .requestingContent else {
            // Note: this should not happen.
            // It is a hint that there is something wrong in the view system that
            // unwarrantably sends `requestContent` events for some reason. This
            // may be caused by a bug in SwiftUI which is still present as of
            // today in version iOS 14.5 where `onAppear` will be called _twice_
            // during one cycle which creates two `requestContent` events.
            print("WARNING: requestContent denied: requestingContent already requested")
            return state
        }

        guard state.status != .mutating else {
            // Note: this should not happen!
            //
            // It is a hint that there is something wrong where something sends
            // unwarrantably `requestContent` events when a mutating IO
            // operation has been started already.
            //
            // This may be caused when there was a previous user action which
            // triggered a mutating IO operation leaving the UI interactable and
            // the same or another user action has been issued triggering
            // another mutating IO operation while the previous is not yet
            // completed. This may be troublesome, since the content is strictly
            // stale after the first mutating action and performing further
            // mutating actions based on stale state can cause errors or worse.
            //
            // A possible remedy of this is to make the UI non-interactable.
            //
            // Note that if a load operation is pending it should be _explicitly_
            // cancelled should it be required to change the load operation.
            //
            // Usually, a pending IO action will be cancelled anyway if a new
            // IO action is started. However, a network call for example, may
            // already be sent out and causes the same load on a server as a
            // request that has been received by the client.
            print("WARNING: trying to request content when a mutation operation is pending. This may cancel the mutating operation.")
            return state
        }
        var state = state
        state.status = .requestingContent
        return state
    }
}

enum ComicSelectionEvent {
    case requestCancel
    case didDismiss
    case requestToggleFavourite
    case requestContent
    case requestShowRandomComic
    case requestShowPreviousComic
    case requestShowNextComic
    case requestShowActualComic
}

class ComicSelectionViewModel: ObservableObject, ViewModel {
    
    typealias Event = ComicSelectionEvent
    
    enum EventInternal {
        case requestCancel
        case didDismiss
        case requestToggleFavourite
        case requestContent
        case requestShowRandomComic
        case requestShowPreviousComic
        case requestShowNextComic
        case requestShowActualComic
        
        case startLoading
        case didCompleteLoading(Result<Comic, Swift.Error>)
        case didToggleFavourite(Bool, id: Int)
        case requestSaveToImageStore
    }
    
    typealias Modal = ModalState<AlertState, SheetState, ActionSheetState, ProgressState>
    typealias ViewState = ComicsExample.ViewState<Either<Comic, NoContent>, Modal>
    
    @Published var viewState = ViewState(content: .left(.blank))
    
    init(favouritesStore: AnyFavouritesStore<Comic, UIImage>) {
        self.state = State(viewState: ViewState(content: .left(.blank)), index: nil)
        self.favouritesStore = favouritesStore
        
        Publishers.system(
            initial: state,
            reduce: Self.reduce,
            feedbacks: [
                userInput(input: input.eraseToAnyPublisher()),
                whenRequestingContent(),
                whenLoadingContent(),
                whenTogglingFavourite(),
            ],
            scheduler: RunLoop.main
        )
        .assign(to: \.state, on: self)
        .store(in: &cancellables)
    }
    
    // The state for the state machine. Contains also the ViewState.
    // TODO: it would be easier to process if State is an Enum!
    //
    // The current logic now remembers the "last" valid index and also assumes
    // that the first valid index equals 1. Whenever an image has been successfully
    // loaded the "last" index will be updated to max(last, currentIndex).
    //
    // "next" and "prev" have been "fixed" (more natural user experiene).
    //
    // Now, "showNextComic" loads at index = ++currentIndex, unless
    // currentIndex equals nil (no comic exists) in which case the actual comic
    // is loaded.
    //
    // Now, "showPreviousComic" loads at index = max(first, --currentIndex), unless
    // currentIndex equals nil (no comic exists) in which case the actual comic
    // is loaded.
    
    private struct State {
        
        enum Mutation {
            case content
            case toggleFavourite(Int)
        }
        
        enum State {
            /// The state machine is dormant and ready to process new events
            case idle
            /// An event has been received which in effect may mutate the view state.
            case requestingContent
            /// Indicates, that the view state is about to change
            case mutating
            case requestingSaveToImageStore
            case savingToImageStore
            case togglingFavourite
        }
        var viewState: ViewState
        var index: Int? = nil // the index which is used when loading.
        var status: State = .idle
        
        let firstIndex = 1
        var lastIndex = 1 // dynamically evaluated "last" valid index; potentially stale after updateing.
    }
    
    private var state: State {
        willSet {
            //dump(state, name: "old")
            //dump(newValue, name: "new")
            self.viewState = newValue.viewState
        }
    }
    
    private let favouritesStore: AnyFavouritesStore<Comic, UIImage>
    private var cancellables: Set<AnyCancellable> = []
    private let input = PassthroughSubject<EventInternal, Never>()
    
    func send(_ event: ComicSelectionEvent) {
        NSLog("*** User command: \(event)")
        switch event {
        case .requestCancel: input.send(.requestCancel)
        case .didDismiss: input.send(.didDismiss)
        case .requestToggleFavourite: input.send(.requestToggleFavourite)
        case .requestContent: input.send(.requestContent)
        case .requestShowRandomComic: input.send(.requestShowRandomComic)
        case .requestShowPreviousComic: input.send(.requestShowPreviousComic)
        case .requestShowNextComic: input.send(.requestShowNextComic)
        case .requestShowActualComic: input.send(.requestShowActualComic)
        }
    }
    
    func dismiss() {
        send(.didDismiss)
    }
    
    // MARK: - Reducer
    
    private static func reduce(_ state: State, _ event: EventInternal) -> State {
        let output: State
        switch event {
        case .requestContent:
            output = requestContent(state)
            
        case .startLoading:
            output = startLoading(state)
            
        case .didCompleteLoading(let result):
            output = didCompleteLoading(with: result, state: state)
            
        case .requestCancel:
            output = requestCancel(state)
            
        case .didDismiss:
            output = didDismiss(state)
            
        case .requestShowActualComic:
            output = showActualComic(state)
            
        case .requestShowNextComic:
            output = requestShowNextComic(state)
            
        case .requestShowPreviousComic:
            output = requestShowPreviousComic(state)
            
        case .requestShowRandomComic:
            output = requestShowRandomComic(state)
            
        case .requestSaveToImageStore:
            output = requestSaveToImageStore(state)
            
        case .requestToggleFavourite:
            output = requestToggleFavourite(state)
            
        case .didToggleFavourite(let value, let id):
            output = didToggleFavourite(state, isFavourite: value, id: id)
        }
        
        print("*** reduce(\(state.status), \(event)) -> \(output.status)")
        return output
    }
    
}



// MARK: - Actions:

extension ComicSelectionViewModel {

    private static func startLoading(_ state: State) -> State {
        var state = state
        state.status = .mutating
        state.viewState.modal = .progress(.init(label: "loading..."))
        return state
    }

    private static func didCompleteLoading(with result: Result<Comic, Swift.Error>, state: State) -> State {
        var state = state
        state.status = .idle
        switch result {
        case .success(let comic):
            // here we assume, the commic id equals the index at where it will
            // be located - which is a reasonable assumption.
            guard let actualIndex = Int(comic.id), actualIndex > 0 else {
                fatalError("implicit assumption invalid: commic id equals path reference {{id}}")
            }
            state.index = actualIndex
            state.viewState = ViewState(content: .right(comic))
            state.lastIndex = max(state.lastIndex, actualIndex)

        case .failure(let error):
            let alert = AlertState(title: "Error", message: String(describing: error))
            state.viewState.modal = .alert(alert)
        }
        return state
    }
}

// MARK: - Feedbacks
extension ComicSelectionViewModel {

    // MARK: Feedback UserInput

    private func userInput(input: AnyPublisher<EventInternal, Never>) -> Feedback<State, EventInternal> {
        Feedback.compact(name: "Input") { (state: State) -> AnyPublisher<EventInternal, Never> in
            input
//            .removeDuplicates(by: { prev, current in
//                if case Event.requestContent = prev, case Event.requestContent = current {
//                    print("removed event: \(current) because it is a duplicate")
//                    return true
//                } else {
//                    return false
//                }
//            })
//            .handleEvents(receiveOutput: { event in
//                print("Received Input: \(event)")
//            })
//            // drop any input as long as state.status is `loading`.
//            .drop(while: { event in
//                if state.status == .loading {
//                    print("Dropped Input: \(event) because state.status equals `loading`")
//                    return true
//                }
//                return false
//
//            })
//            .prepend(Empty())
//                //.debounce(for: 0.25, scheduler: RunLoop.main)
//            .eraseToAnyPublisher()
        }
    }

    // MARK: Feedback RequestContent

    // If state equals `requestingContent` emit an `Event.startLoading`.
    // Here, when receiving the event, the reducer sets the view model into a
    // modal loading state emitting a corresponding view state and transitions
    // to state `loadingContent`.
    private func whenRequestingContent() -> Feedback<State, EventInternal> {
        Feedback.compact(name: "RequestContent") { (state: State) -> AnyPublisher<EventInternal, Never> in
            guard case .requestingContent = state.status else {
                return Empty().eraseToAnyPublisher()
            }
            return Just(EventInternal.startLoading)
            .eraseToAnyPublisher()
        }
    }


    // MARK: Feedback LoadContent

    // If state equals `loadingContent` start a loading operation.
    // Note that any received stimuli will cancel a pending load operation.
    private func whenLoadingContent() -> Feedback<State, EventInternal> {
        Feedback.compact(name: "LoadContent") { (state: State) -> AnyPublisher<EventInternal, Never> in
            guard case .mutating = state.status else {
                return Empty().eraseToAnyPublisher()
            }
            let comic = ComicAPI.comic(state.index)
                .flatMap { dto in
                    self.favouritesStore.isFavourite(withId: String(dto.num))
                    .map { isFavourite in
                        Comic(dtoComic: dto, isFavourite: isFavourite)
                    }
                    .mapError(ComicAPI.Error.internal)
                }
                .map { comic in
                    EventInternal.didCompleteLoading(.success(comic))
                }
                .catch { error in
                    Just(EventInternal.didCompleteLoading(.failure(error)))
                }

            return comic
                .eraseToAnyPublisher()
        }
    }

    
    // MARK: Feedback SaveImage

    private func whenSavingToImageStore() -> Feedback<State, EventInternal> {
        Feedback.compact(name: "SaveImage") { (state: State) -> AnyPublisher<EventInternal, Never> in
            // Not yet implemented
            return Empty().eraseToAnyPublisher()
        }
    }

    // MARK: Feedback ToggleFavourite

    private func whenTogglingFavourite() -> Feedback<State, EventInternal> {
        Feedback.compact(name: "ToggleFavourite") { (state: State) -> AnyPublisher<EventInternal, Never> in
            guard case .togglingFavourite = state.status,
                  let comic = state.viewState.content.right,
                  let id = Int(comic.id)
            else {
                return Empty().eraseToAnyPublisher()
            }
            return self.favouritesStore.toggleFavourite(comic)
            .map { _ in
                EventInternal.didToggleFavourite(!comic.isFavourite, id: id)
            }
            .replaceError(with: EventInternal.didToggleFavourite(comic.isFavourite, id: id))
            .eraseToAnyPublisher()
        }
    }

}


#endif
