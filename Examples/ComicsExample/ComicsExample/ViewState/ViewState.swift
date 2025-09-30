// MARK: - State

public enum Either<Right, Left> {
    case right(Right)
    case left(Left)

    public var left: Left? {
        if case .left(let left) = self {
            return left
        }
        return nil
    }

    public var right: Right? {
        if case .right(let right) = self {
            return right
        }
        return nil
    }
}

extension Either: Equatable where Left: Equatable, Right: Equatable {
    public static func == (lhs: Either<Right, Left>, rhs: Either<Right, Left>) -> Bool {
        if let lhsLeft = lhs.left, let rhsLeft = rhs.left {
            return lhsLeft == rhsLeft
        } else if let lhsRight = lhs.right, let rhsRight = rhs.right {
            return lhsRight == rhsRight
        } else {
            return false
        }
    }
}

@dynamicMemberLookup
public struct ViewState<Content, Modal> {
    public typealias Content = Content
    public typealias Modal = Modal

    public var content: Content
    public var modal: Modal?

    public init(content: Content) {
        self.content = content
        self.modal = nil
    }

    public init(content: Content, modal: Modal?) {
        self.content = content
        self.modal = modal
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<Modal, T?>) -> T? {
        get {
            if let modal = self.modal {
                return modal[keyPath: keyPath]
            } else {
                return nil
            }
        }
        set {
            self.modal = nil
        }
    }
}


public enum NoContent {
    case blank
    case empty(title: String, description: String)
    case error(title: String, description: String)

    public var isBlank: Bool {
        if case .blank = self {
            return true
        }
        return false
    }

    public var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    public var isEmpty: Bool {
        if case .empty = self {
            return true
        }
        return false
    }
}

extension NoContent: Equatable {}

public struct Empty {}


public extension Either where Left == NoContent {
    var isSome: Bool {
        return self.right != nil
    }

    var isNone: Bool {
        return self.left != nil
    }

    var isBlank: Bool {
        switch self {
        case .left(let what) where what == .blank:
            return true
        default:
            return false
        }
    }

    var isEmpty: Bool {
        switch self {
        case .left(let what) where what.isEmpty:
            return true
        default:
            return false
        }
    }

    var isError: Bool {
        switch self {
        case .left(let what) where what.isEmpty:
            return true
        default:
            return false
        }
    }
}
