extension States {

    @dynamicMemberLookup
    public enum ContentState<Content, NoContent> {
        case present(Content)
        case absent(NoContent)

        // Standard property access
        public var content: Content? {
            if case .present(let content) = self { return content }
            return nil
        }

        public var absence: NoContent? {
            if case .absent(let noContent) = self { return noContent }
            return nil
        }

        public var isPresent: Bool {
            if case .present = self { return true }
            return false
        }

        public var isAbsent: Bool {
            if case .absent = self { return true }
            return false
        }

        // Dynamic member lookup for ergonomic access to Content properties
        public subscript<T>(dynamicMember keyPath: KeyPath<Content, T>) -> T? {
            if case .present(let content) = self {
                return content[keyPath: keyPath]
            }
            return nil
        }

        // For writable properties (if needed)
        public subscript<T>(dynamicMember keyPath: WritableKeyPath<Content, T>) -> T? {
            get {
                if case .present(let content) = self {
                    return content[keyPath: keyPath]
                }
                return nil
            }
            set {
                // Note: This would require making ContentState mutable
                // and handling the case where we're absent
                guard case .present(var content) = self, let newValue = newValue else { return }
                content[keyPath: keyPath] = newValue
                self = .present(content)
            }
        }
    }
    
}
