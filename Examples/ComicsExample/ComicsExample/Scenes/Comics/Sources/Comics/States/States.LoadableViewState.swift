import Foundation

extension States {

    enum LoadableViewState<
        Content: DefaultConstructible,
        Activity,
        Presentation: Identifiable,
        Failure: LocalizedError
    >: States.ViewState {
        // represents an uninitialised actor
        case start
        // the actor is ready to execute a task
        case idle(content: Content)
        // the actor is busy with executing a task
        case busy(Activity, content: Content)
        // the actor is in a modal failure state
        case failure(Failure, content: Content)
        // the actor in a modal state wating for user input
        case presenting(Presentation, content: Content)
    }
}

// Convenience accessors
extension States.LoadableViewState {
    
    init(content: Content) {
        self = .idle(content: content)
    }
    
    var content: Content {
        switch self {
        case .idle(let content),
             .busy(_, let content),
             .failure(_, let content),
             .presenting(_, let content):
            return content
        case .start:
            return Content()
        }
    }
    
    var activity: Activity? {
        if case .busy(let activity, _) = self {
            return activity
        }
        return nil
    }
    
    var presentation: Presentation? {
        if case .presenting(let presentation, _) = self {
            return presentation
        }
        return nil
    }
    
    var failure: Failure? {
        if case .failure(let error, _) = self {
            return error
        }
        return nil
    }
    
    var isStart: Bool {
        if case .start = self { return true }
        return false
    }
    
    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
    
    var isBusy: Bool {
        if case .busy = self { return true }
        return false
    }
    
    var isPresenting: Bool {
        if case .presenting = self { return true }
        return false
    }
    
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}

extension States.LoadableViewState {
    mutating func transitionToIdle() {
        switch self {
        case .idle:
            break
        case .busy(_, let content),
             .failure(_, let content),
             .presenting(_, let content):
            self = .idle(content: content)
        case .start:
            fatalError("Cannot transition from start to idle without content")
        }
    }
    
    func idle() -> Self {
        switch self {
        case .idle:
            return self
        case .busy(_, let content),
             .failure(_, let content),
             .presenting(_, let content):
            return .idle(content: content)
        case .start:
            fatalError("Cannot transition from start to idle without content")
        }
    }


    mutating func transitionToBusy(_ activity: Activity) {
        switch self {
        case .idle(let content),
             .busy(_, let content),
             .failure(_, let content):
            self = .busy(activity, content: content)
        case .presenting(_, _):
            fatalError("Cannot transition from presenting to busy")
        case .start:
            fatalError("Cannot transition from start to busy without content")
        }
    }
    
    func busy(_ activity: Activity) -> Self {
        switch self {
        case .idle(let content),
             .busy(_, let content),
             .failure(_, let content):
            return .busy(activity, content: content)
        case .presenting(_, _):
            fatalError("Cannot transition from presenting to busy")
        case .start:
            fatalError("Cannot transition from start to busy without content")
        }
    }


    mutating func transitionToPresenting(_ presentation: Presentation) {
        switch self {
        case .idle(let content),
             .busy(_, let content),
             .failure(_, let content):
            self = .presenting(presentation, content: content)
        case .presenting:
            fatalError("Cannot present while already presenting")
        case .start:
            fatalError("Cannot transition from start to presenting without content")
        }
    }
    
    func presenting(_ presentation: Presentation) -> Self {
        switch self {
        case .idle(let content),
             .busy(_, let content),
             .failure(_, let content):
            return .presenting(presentation, content: content)
        case .presenting:
            fatalError("Cannot present while already presenting")
        case .start:
            fatalError("Cannot transition from start to presenting without content")
        }
    }

}

extension States.LoadableViewState: Equatable where Content: Equatable, Activity: Equatable, Presentation: Equatable, Failure: Equatable {}

extension States.LoadableViewState: CustomStringConvertible {
    
    var description: String {
        switch self {
        case .start:
            return "Start"
        case .idle:
            return "Idle"
        case .busy(let activity, _):
            return "Busy: \(activity)"
        case .failure(let error, _):
            return "Failure: \(error)"
        case .presenting(let presentation, _):
            return "Presenting: \(presentation)"
        }
    }
}
