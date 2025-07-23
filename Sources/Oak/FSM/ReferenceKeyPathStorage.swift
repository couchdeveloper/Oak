

internal struct ReferenceKeyPathStorage<Host, Value>: Storage {
    
    init(host: Host, keyPath: ReferenceWritableKeyPath<Host, Value>) {
        self.host = host
        self.keyPath = keyPath
    }
    
    private let host: Host
    private let keyPath: ReferenceWritableKeyPath<Host, Value>
    
    var value: Value {
        get {
            host[keyPath: keyPath]
        }
        nonmutating set {
            host[keyPath: keyPath] = newValue
        }
    }
}

