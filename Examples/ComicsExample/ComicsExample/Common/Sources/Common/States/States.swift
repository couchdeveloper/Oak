// TODO: Refactor into module

public enum States {
    
    public protocol DefaultConstructible {
        init()
    }

    public protocol ViewState {
        associatedtype Content: DefaultConstructible
        associatedtype Activity
        associatedtype Presentation: Identifiable
        associatedtype Failure
        
        var content: Content { get }
        var activity: Activity? { get }
        var presentation: Presentation? { get }
        var failure: Failure? { get }
        
        var isBusy: Bool { get }
        var isIdle: Bool { get }
        var isFailure: Bool { get }
        var isPresenting: Bool { get }
    }

}

extension States {
    public enum Activity {
        case indeterminate(title: String = "")
    }
    
    public struct Action<Value> {
        public let title: String
        public let action: (Value) -> Void
        
        public func callAsFunction(_ value: Value) {
            self.action(value)
        }
    }
}

extension States.Action where Value == Void {
    public func callAsFunction() {
        self.callAsFunction(Void())
    }
}
