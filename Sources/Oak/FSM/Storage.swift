package protocol Storage<Value> {
    associatedtype Value
    
    var value: Value { get nonmutating set }
    
    func lock()
    func unlock()
}

package extension Storage {
    // Default is no-op
    func lock() {}
    // Default is no-op
    func unlock() {}
}

internal struct LocalStorage<Value>: Storage {
    final class Reference {
        var value: Value

        init(value: Value) {
            self.value = value
        }
    }
    
    init(value: Value) {
        storage = Reference(value: value)
    }
    
    private let storage: Reference
    
    var value: Value {
        get {
            storage.value
        }
        nonmutating set {
            storage.value = newValue
        }
    }
}


// See also: https://forums.swift.org/t/keypath-performance/60487/2
