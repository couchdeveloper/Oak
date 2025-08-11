import Oak

// MARK: - Utilities


enum NavigationSplitViewUtilities {
    
    // A Reusable State for "loading resources" scenarios
    public enum State<Data, Sheet, Error, Context>: NonTerminal {
        case start  // Initial state - equivalent to .idle(.empty(nil))
        case idle(Content, Context)  // Context contains actor components (always present)
        case modal(Modal, Content, Context)  // Context always present in operational states
        
        enum Empty {
            case blank
            case filled(title: String, description: String, actions: [Intent])
        }
        
        struct Intent {
            init(title: String, description: String? = nil, action: @escaping () -> Void) {
                self.title = title
                self.description = description
                self.action = action
            }
            let title: String
            let description: String?
            let action: () -> Void
        }
        
        struct Loading {
            let title: String
            let description: String = ""
            let cancelAction: Intent? = nil
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
            case loading(Loading?)  // nil = default
            case error(Error)
            case sheet(Sheet?)
            
            var isLoading: Bool {
                switch self {
                case .loading:
                    return true
                default:
                    return false
                }
            }
        }
    }
}

extension NavigationSplitViewUtilities.State {
        

    var isLoading: Bool {
        switch self {
        case .modal(let modal,_, _):
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
        case .modal(let modal, _, _):
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
        case .modal(let modal,_, _):
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
        case .modal(let modal,_, _):
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
        case .modal(_, let content, _):
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
        case .modal(_, let content, _):
            return content
        case .start:
            return .empty(nil)
        }
    }
}


