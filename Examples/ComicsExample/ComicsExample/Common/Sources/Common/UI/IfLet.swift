import SwiftUI

public struct IfLet<T, Content: View>: View {
    let value: T?
    let content: (T) -> Content

    public init(_ value: T?, content: @escaping (T) -> Content) {
        self.value = value
        self.content = content
    }

    public init(_ binding: Binding<T?>, content: @escaping (T) -> Content) {
        self.value = binding.wrappedValue
        self.content = content
    }

    public var body: some View {
        if let value {
            content(value)
        } else {
            Color.clear
        }
    }
}
