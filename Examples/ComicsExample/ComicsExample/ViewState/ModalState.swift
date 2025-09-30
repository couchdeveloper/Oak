public protocol Dismissable {
    func dismiss()
}

public protocol Modality {
    associatedtype Alert
    associatedtype Sheet
    associatedtype ActionSheet
    associatedtype Progress

    var alert: Alert? { get }
    var sheet: Sheet? { get }
    var actionSheet: ActionSheet? { get }
    var progress: Progress? { get }
}

public enum ModalState<
    Alert: Identifiable,
    Sheet: Identifiable,
    ActionSheet: Identifiable,
    Progress
> {
    case alert(Alert)
    case sheet(Sheet)
    case actionSheet(ActionSheet)
    case progress(Progress)
}

extension ModalState: Modality {
    public var alert: Alert? {
        if case .alert(let alert) = self {
            return alert
        }
        return nil
    }
    public var sheet: Sheet? {
        if case .sheet(let sheet) = self {
            return sheet
        }
        return nil
    }
    public var actionSheet: ActionSheet? {
        if case .actionSheet(let actionSheet) = self {
            return actionSheet
        }
        return nil
    }
    public var progress: Progress? {
        if case .progress(let progress) = self {
            return progress
        }
        return nil
    }
}

public struct AlertState: Identifiable {
    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public let id = 0
    public var title: String
    public var message: String
}

public struct SheetState: Identifiable {
    public init() {}

    public let id = 0
}

public struct ActionSheetState: Identifiable {
    public init(title: String) {
        self.title = title
    }

    public let id = "0"
    public var title: String
}

public struct ProgressState {
    public init(label: String = "") {
        self.label = label
    }

    let label: String
    
    static let loading = ProgressState()
}
