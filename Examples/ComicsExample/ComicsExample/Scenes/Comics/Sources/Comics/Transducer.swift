import Oak

// MARK: - Transducer

enum Transducer: EffectTransducer {
    
    typealias Content = States.ContentState<Comic, States.NoContent>
    
    struct Loading {
        static let loading = Loading()
        var description: String? = ""
    }
    
    struct Presentation: Identifiable {
        let id = 0
    }
    
    typealias Error = ComicsError
    
    typealias ViewState = States.LoadableViewState<Content, Loading, Presentation, Error>
    
    struct State: NonTerminal {
        var viewState: ViewState = .start
    }

    typealias Env = ComicsEnv
    
    enum Event {
        // Initial setup of the state.
        case start(content: Content = .absent(.blank))
        // Sent by the views when a content (aka `Comic`) needs to be loaded.
        case requestContent
        // User cancels any modal activity.
        case intentCancel
        // User tapped the "Next" button
        case intentShowNextComic
        // User tapped the "Previous" button
        case intentShowPreviousComic
        // User tapped the "Favourite" button
        case intentToggleFavourite
        // User tapped the "Show random comic" button
        case intentShowRandomComic
        // User tapped the "Show actula comic" button
        case intentShowActualComic
        // User dismissed any Alert
        case didDismiss
        // Servive returned an image
        case didCompleteLoading(Result<Comic, Error>)
                
        // case didToggleFavourite(Bool, id: Int) // not yet implemented
        // case requestSaveToImageStore  // not yet implemented
    }
    
    static func update(_ state: inout State, event: Event) -> Self.Effect? {
        switch (state.viewState, event) {
        case (.start, .start(let contentState)):
            // Note: in any case, the image needs to be loaded - which is done
            // by the views.
            state.viewState = ViewState(content: contentState)
            switch contentState {
                case .absent: // no content - get the actual comic:
                // we do not transition to another state!
                return (.event(.requestContent))
            case .present(_): // we have content - we are done
                state.viewState.transitionToIdle()
                return nil
            }

        case (.start, .requestContent):
            // Load the actual comic:
            state.viewState = ViewState(content: .absent(.blank)).busy(.loading)
            return loadActualComic()
            
        case (.busy(_, let content), .didCompleteLoading(let result)):
            switch result {
            case .success(let comic):
                state.viewState = .idle(content: .present(comic))
                return nil
            case .failure(let error):
                state.viewState = .failure(error, content: content)
                return nil
            }
            
        case (.failure(let error, let content), .didDismiss):
            // if the content is case `left` (aka `NoContent`, we should add a
            // Button to it, which sends `requestContent` when tapped.
            switch content {
            case .absent:
                // Not yet implemented:
                // let action = States.Action<Void>(title: "Retry") {
                //     state.input.send(event: .requestContent)
                // }
                state.viewState = .idle(content: .absent(
                    .error(title: "Error", description: error.localizedDescription)
                ))
                return nil
            case .present:
                state.viewState.transitionToIdle()
                return nil
            }

        case (.idle(.absent), .requestContent):
            state.viewState.transitionToBusy(.loading)
            return loadActualComic()

        case (.idle(.present(let comic)), .intentShowNextComic):
            let currentId = comic.id
            let id = currentId + 1
            state.viewState.transitionToBusy(.loading)
            return loadComic(id: id)

        case (.idle(.present(let comic)), .intentShowPreviousComic):
            let currentId = comic.id
            let id = currentId - 1
            guard id > 0 else {
                return nil
            }
            state.viewState.transitionToBusy(.loading)
            return loadComic(id: id)

        case (.idle(_), .intentShowActualComic):
            state.viewState.transitionToBusy(.loading)
            return loadActualComic()

        case (.idle(_), .intentShowRandomComic):
            state.viewState.transitionToBusy(.loading)
            return loadRandomComic()
            
        case (.busy, .intentCancel):
            return .cancelTask("loadComic")

        case (.busy, _):
            return nil

        // more cases ...
        
        // Note: "toggle favorite" should not be implemented yet
        case (_, .intentToggleFavourite):
            return nil
            
            
        default:
            fatalError("unhandled case: \(state), \(event)")
        }
    }
    
    // MARK: - Effects
    
    static func loadComic(id: Int) -> Self.Effect {
        Effect(id: "loadComic") { env, input in
            do {
                let comic = try await env.loadComic(id)
                try input.send(.didCompleteLoading(.success((comic))))
            } catch let error as Comics.Transducer.Error {
                // Note: we only reach here, when `loadComic` failed in order
                // continue to run the transducer and handle the error.
                // Otherwise, and when either `send` failed, we bail out and
                // the transducer will terminate - which is what we want to
                // achieve.
                try input.send(.didCompleteLoading(.failure(error)))
            }
        }
    }
    
    static func loadActualComic() -> Self.Effect {
        Effect(id: "loadComic") { env, input in
            do {
                let comic = try await env.loadActualComic()
                try input.send(.didCompleteLoading(.success((comic))))
            } catch let error as Comics.Transducer.Error {
                // Note: we only reach here, when `loadActualComic` failed in
                // order to continue to run the transducer and handle the error.
                // Otherwise, and when either `send` failed, we bail out and
                // the transducer will terminate - which is what we want to
                // achieve.
                try input.send(.didCompleteLoading(.failure(.other(error))))
            }
        }
    }
    
    
    static func loadRandomComic() -> Self.Effect {
        Effect(id: "loadComic") { env, input in
            do {
                let comic = try await env.loadActualComic()
                let randomId = Int.random(in: 1...comic.id)
                let comic2 = try await env.loadComic(randomId)
                try input.send(.didCompleteLoading(.success((comic2))))
            } catch let error as Comics.Transducer.Error {
                // Note: we only reach here, when `loadActualComic` or `loadComic`
                // failed. We to continue to run the transducer and handle the
                // error. Otherwise, and when either `send` failed, we bail out
                // and the transducer will terminate - which is what we want to
                // achieve.
                try input.send(.didCompleteLoading(.failure(.other(error))))
            }
        }
    }

}
