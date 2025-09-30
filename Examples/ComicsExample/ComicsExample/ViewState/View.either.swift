import SwiftUI

public extension View {
    @ViewBuilder
    func either<Right, Left, RightContent, LeftContent>(
        _ either: Either<Right, Left>,
        right: (Right) -> RightContent,
        left: (Left) -> LeftContent
    ) -> some View where RightContent: View, LeftContent: View {
        switch either {
        case .right(let state):
        right(state)
        case .left(let state):
            left(state)
        }
    }
}
