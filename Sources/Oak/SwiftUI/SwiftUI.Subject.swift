#if canImport(SwiftUI)
import SwiftUI

extension Binding: Subject {
    public func send(
        _ value: sending Value,
        isolated: isolated any Actor
    ) async throws {
        self.wrappedValue = value
    }
}
#endif  // canImport(SwiftUI)
