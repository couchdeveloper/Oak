enum States {}

extension States {
    enum Activity {
        case indeterminate(title: String = "")
    }
    
    
    struct Action<Value> {
        let title: String
        let action: (Value) -> Void
        
        func callAsFunction(_ value: Value) {
            self.action(value)
        }
    }
}

extension States.Action where Value == Void {
    func callAsFunction() {
        self.callAsFunction(Void())
    }

}
