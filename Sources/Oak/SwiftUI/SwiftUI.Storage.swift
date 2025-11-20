#if canImport(SwiftUI)
import SwiftUI

extension SwiftUI.Binding: Storage {
    public var value: Value {
        get {
            self.wrappedValue
        }
        nonmutating set {
            self.wrappedValue = newValue
        }
    }
}
#endif
