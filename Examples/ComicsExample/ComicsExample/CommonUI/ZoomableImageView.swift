import SwiftUI
import Nuke

struct ZoomableImageView: View {
    @StateObject private var image = FetchImage()
    let url: URL
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Rectangle().fill(Color.clear)
            if image.isLoading {
                Text("loading...")
                    .font(.system(size: 8, weight: .light))
            } else if let imageView = image.view {
                imageView
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .clipped()
                    .gesture(MagnificationGesture()
                        .onChanged { value in
                            print("scale: \(value)")
                            self.scale = max(0.5, min(2, value.magnitude))
                        }
                        .onEnded({ _ in
                            withAnimation(.spring()) {
                                self.scale = 1.0
                            }
                        })
                    )
            } else {
                Image(systemName: "xmark.octagon")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.red)
                    .padding(10)
            }
        }
        .onAppear {
            print("ImageView onAppear")
            guard image.image == nil, !image.isLoading else {
                return
            }
            image.load(url)
        }
        .onChange(of: url) { image.load($0) }
        .onDisappear {
            print("ImageView onDisappear")
            //image.reset()
        }
        .transition(AnyTransition.opacity.animation(.easeInOut(duration: 3.0)))
    }
}

// MARK: - Previews

struct ImageView_Previews: PreviewProvider {
    static var previews: some View {
        ZoomableImageView(url: URL(string: "https://picsum.photos/800/1600")!)
    }
}
