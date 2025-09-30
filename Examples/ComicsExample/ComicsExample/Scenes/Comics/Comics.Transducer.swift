import Oak

extension Comics { enum Transducer: EffectTransducer {
    typealias Modal = ModalState<AlertState, SheetState, ActionSheetState, ProgressState>
    typealias ViewState = ComicsExample.ViewState<Either<Comic, NoContent>, Modal>
    
    struct Env {
        var loadComic: (Int) async throws -> Comic
        var loadActualComic: () async throws -> Comic
    }
    
    typealias Output = ViewState
    
    typealias Content = Either<Comic, NoContent>

    enum Event {
        case start(content: Content = .left(.blank))
        case requestContent
        case intentCancel
        case intentShowNextComic
        case intentShowPreviousComic
        case intentToggleFavourite
        case intentShowRandomComic
        case intentShowActualComic
        case didDismiss

        case didCompleteLoading(Result<Comic, Swift.Error>)
                
        // case didToggleFavourite(Bool, id: Int) // not yet implemented
        // case requestSaveToImageStore  // not yet implemented
    }
    
    
    enum State: NonTerminal  {
        /// Represents an unintialised state.
        case start
        
        /// The state machine is ready to process new events.
        case idle(content: Content, lastIndex: Int)
        
        /// An event has been received which in effect may mutate the view state.
        case loading(index: Int, content: Content, lastIndex: Int)

        /// A modal error state
        case modalError(Error, content: Content, lastIndex: Int)
        
        // the index which is used when loading.
        var loadingIndex: Int? {
            if case .loading(let index, _, _) = self { index } else { nil }
        }
        
        static let firstIndex = 1
        
        // dynamically evaluated "last" valid index; potentially stale after updateing.
        var lastIndex: Int {
            switch self {
            case .idle(_, lastIndex: let lastIndex): return lastIndex
            case .loading(_, _, lastIndex: let lastIndex): return lastIndex
            case .modalError(_, _, lastIndex: let lastIndex): return lastIndex
            case .start: return 1
            }
        }
        
        var error: Swift.Error? {
            if case .modalError(let error, _, _) = self { error } else { nil }
        }
    }
    
    static func update(_ state: inout State, event: Event) -> (Self.Effect?, ViewState) {
        switch (state, event) {
        case (.start, .start(let content)):
            state = .idle(content: content, lastIndex: 1)
            let viewState = ViewState(content: content)
            return (nil, viewState)

        case (.idle(.right(let comic), let lastIndex), .requestContent):
            guard let id = Int(comic.id) else {
                fatalError("invalid comic id: \(comic.id)")
            }
            state = .loading(index: id, content: .right(comic), lastIndex: lastIndex)
            let viewState = ViewState(content: .right(comic), modal: .progress(.loading))
            return (loadComic(id: id), viewState)

        case (.idle(.left, let lastIndex), .requestContent):
            state = .loading(index: 0, content: .left(.blank), lastIndex: lastIndex)
            let viewState = ViewState(content: .left(.blank), modal: .progress(.loading))
            return (loadActualComic(), viewState)

        }
    }
    
    static func loadComic(id: Int) -> Self.Effect {
        Effect(id: "loadComic") { env, input in
            do {
                let comic = try await env.loadComic(id)
                try? input.send(.didCompleteLoading(.success((comic))))
            } catch {
                try? input.send(.didCompleteLoading(.failure(error)))
            }
        }
    }
    
    static func loadActualComic() -> Self.Effect {
        Effect(id: "loadComic") { env, input in
            do {
                let comic = try await env.loadActualComic()
                try? input.send(.didCompleteLoading(.success((comic))))
            } catch {
                try? input.send(.didCompleteLoading(.failure(error)))
            }
        }
    }
}}
