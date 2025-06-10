import SwiftUI

extension Binding: Oak.Subject {
    public func send(_ value: Value) async throws {
        self.wrappedValue = value
    }
}
