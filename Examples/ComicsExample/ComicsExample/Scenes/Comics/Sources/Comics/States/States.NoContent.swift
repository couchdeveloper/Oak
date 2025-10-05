extension States {
    
    public enum NoContent {
        case blank
        case empty(title: String, description: String, action: Action<Void>? = nil)
        case error(title: String, description: String, action: Action<Void>? = nil)
        
        public var isBlank: Bool {
            if case .blank = self { return true }
            return false
        }
        
        public var isEmpty: Bool {
            if case .empty = self { return true }
            return false
        }

        public var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }
}
