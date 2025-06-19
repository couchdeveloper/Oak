#if canImport(SwiftUI)
import SwiftUI

extension Binding: Oak.Subject {
    public func send(_ value: sending Value) async throws {
        self.wrappedValue = value
    }
}
#endif // canImport(SwiftUI)
