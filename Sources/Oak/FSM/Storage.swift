/// A protocol that abstracts different storage implementations for transducer state.
///
/// This protocol is used internally by the Oak framework to provide a unified interface
/// for various storage types including local storage, KeyPath-based storage, and SwiftUI Bindings.
/// Users typically won't interact with this protocol directly.
public protocol Storage<Value> {
    associatedtype Value
    
    var value: Value { get nonmutating set }
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
