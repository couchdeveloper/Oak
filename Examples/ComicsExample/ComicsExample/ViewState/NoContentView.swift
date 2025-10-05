#if false
// This is OBSOLETE!

import SwiftUI

public struct NoContentView: View {
    var state: NoContent

    public init(state: NoContent) {
        self.state = state
    }
    public var body: some View {
        GeometryReader { proxy in
            switch state {
            case .blank:
                Color.systemGray5
            case .empty(let title, let description):
                HStack(alignment: .top) {
                    Spacer()
                    VStack {
                        Spacer()
                        Image(systemName: "xmark.rectangle.portrait")
                            .font(.system(size: 60.0, weight: .ultraLight))
                            .foregroundColor(Color.secondaryLabel)
                            .padding(10)
                        Text(title)
                            .font(.headline)
                            .foregroundColor(Color.secondaryLabel)
                            .padding(4)
                        Text(description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color.secondaryLabel)
                        Spacer()
                    }
                    .frame(maxWidth: CGFloat(Int(proxy.size.width * 0.7)))
                    Spacer()
                }
                .background(Color.systemGray5)

            case .error(let title, let description):
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        Image(systemName: "xmark.octagon.fill")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.red)
                            .padding(10)
                        VStack {
                            Text(title)
                                .font(.largeTitle)
                                .foregroundColor(Color.secondaryLabel)
                                .padding(4)
                            Text(description)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(Color.secondaryLabel)
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: CGFloat(Int(proxy.size.width * 0.7)))
                        Spacer()
                    }
                    Spacer()
                }
                .background(Color.systemGray5)
            }
        }
    }
}



// MARK: - Preview

private struct ContentView: View {
    let state: NoContent

    var body: some View {
        NoContentView(state: state)
    }
}

struct NoContentView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            ContentView(state: .blank)
                .preferredColorScheme(.light)
            ContentView(state: .blank)
                .preferredColorScheme(.dark)

            ContentView(state: .empty(title: "Empty", description: "No data available"))
                .preferredColorScheme(.light)
            ContentView(state: .empty(title: "Empty", description: "No data available"))
                .preferredColorScheme(.dark)

            ContentView(state: .error(title: "Error", description: "An Error occurred.\nPlease try again later."))
            ContentView(state: .error(title: "Error", description: "An Error occurred.\nPlease try again later."))
                .preferredColorScheme(.dark)
        }
    }
}
#endif
