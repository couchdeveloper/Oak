import Oak

// MARK: - Utilities


enum NavigationSplitViewUtilities {
    
    // A Reusable State for "loading resources" scenarios
    public enum State<Data, Sheet, Error, Context>: NonTerminal {
        public typealias Data = Data
        public typealias Sheet = Sheet
        public typealias Error = Error
        public typealias Context = Context

        case start  // Initial state - equivalent to .idle(.empty(.blank))
        case idle(Content, context: Context)  // Context contains actor components (always present)
        case modal(Modal, content: Content, context: Context)  // Context always present in operational states
        
        public enum Empty {
            case blank
            case filled(title: String, subTitle: String, actions: [Intent])
        }
        
        public struct Intent {
            init(title: String, subTitle: String? = nil, action: @escaping () -> Void) {
                self.title = title
                self.subTitle = subTitle
                self.action = action
            }
            let title: String
            let subTitle: String?
            let action: () -> Void
        }
        
        public struct Activity {
            public let title: String = "Loading…"
            public let subTitle: String = ""
            public let cancelAction: Intent? = nil
        }
        
        public enum Content {
            case none(Empty = .blank)
            case some(Data)
            
            var isEmpty: Bool {
                if case .none = self {
                    return true
                }
                return false
            }
            
            public var data: Data? {
                if case .some(let data) = self {
                    return data
                }
                return nil
            }
        }
        
        public enum Modal {
            case activity(Activity = .init())
            case error(Error)
            case sheet(Sheet)
            
            public var activity: Activity? {
                switch self {
                case .activity(let activity):
                    return activity
                default:
                    return nil
                }
            }
            
            var error: Error? {
                switch self {
                case .error(let error):
                    return error
                default:
                    return nil
                }
            }
            
            var sheet: Sheet? {
                switch self {
                case .sheet(let sheet):
                    return sheet
                default:
                    return nil
                }
            }
        }
        
        var content: Content {
            get {
                switch self {
                case .start:
                    return .none(.blank)
                case .idle(let content, _):
                    return content
                case .modal(_, let content, _):
                    return content
                }
            }
            set {
                switch self {
                case .start:
                    break // cannot set content, we need a context!
                case .idle(_, let context):
                    self = .idle(newValue, context: context)
                case .modal(let modal, _, let context):
                    self = .modal(modal, content: newValue, context: context)
                }
            }
        }
        
        var modal: Modal? {
            switch self {
            case .modal(let modal, _, _):
                return modal
            case .idle, .start:
                return nil
            }
        }
        
        var isStarted: Bool {
            switch self {
            case .start:
                return false
            default:
                return true
            }
        }
        
    }
}


extension NavigationSplitViewUtilities.State: CustomStringConvertible {
    var description: String {
        switch self {
        case .start:
            return "start"
            
        case .idle(let content, _):
            return "idle(\(content))"
            
        case .modal(let modal, let content, _):
            return "modal(\(modal), \(content))"
        }
    }
}

extension NavigationSplitViewUtilities.State.Content: CustomStringConvertible {
    var description: String {
        switch self {
        case .none(let empty):
            return "empty(\(empty))"
        case .some:
            return "data"
        }
    }
}

extension NavigationSplitViewUtilities.State.Empty: CustomStringConvertible {
    var description: String {
        switch self {
        case .blank:
            return "blank"
        case .filled(let title, _, let actions):
            let actionCount = actions.isEmpty ? "" : ", \(actions.count) actions"
            return "filled(\"\(title)\"\(actionCount))"
        }
    }
}

extension NavigationSplitViewUtilities.State.Modal: CustomStringConvertible {
    var description: String {
        switch self {
        case .activity(let activity):
            return "activity(\(activity))"
        case .error:
            return "error"
        case .sheet:
            return "sheet"
        }
    }
}

extension NavigationSplitViewUtilities.State.Activity: CustomStringConvertible {
    var description: String {
        let cancelDesc = cancelAction != nil ? ", cancellable" : ""
        return "\"\(title)\"\(cancelDesc)"
    }
}

extension NavigationSplitViewUtilities.State.Intent: CustomStringConvertible {
    var description: String {
        if let subTitle = subTitle {
            return "\"\(title)\": \"\(subTitle)\""
        } else {
            return "\"\(title)\""
        }
    }
}