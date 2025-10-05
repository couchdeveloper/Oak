import SwiftUI
import Nuke

struct ZoomableImageView: View {
    let url: URL

    @State private var scale: CGFloat = 1.0
    @State private var imageState: ImageState = .start

    enum ImageState {
        case start
        case loading(url: URL, imageTask: ImageTask)
        case cancelled
        case completed(Result<Common.PlatformImage, Swift.Error>)
        
        func cancel() {
            switch self {
            case .loading(_, let imageTask):
                imageTask.cancel()
            default:
                break
            }
        }
    }
    
    var body: some View {
        ZStack {
            switch imageState {
            case .start:
                Color.clear
            
            case .loading(url: _, imageTask: _):
                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .light))
                    .tint(Color.gray)
                    .padding(10)
                
            case .cancelled:
                Image(systemName: "photo.trianglebadge.exclamationmark")
                    .font(.system(size: 20, weight: .light))
                    .tint(.yellow)
                    .padding(10)

            case .completed(.success(let image)):
                image.image
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

            case .completed(.failure(_)):
                Image(systemName: "xmark.octagon")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.red)
                    .padding(10)
            }
        }
        .task(id: url) {
            imageState.cancel()
            let imageTask = ImagePipeline.shared.imageTask(with: url)
            imageState = .loading(
                url: url,
                imageTask: imageTask
            )
            do {
                let image = try await imageTask.image
                self.imageState = .completed(.success(image))
            } catch {
                self.imageState = .completed(.failure(error))
            }
        }
        .onDisappear {
            switch imageState {
            case .loading(_, let imageTask):
            imageTask.cancel()
            default:
                break
            }
        }
        .transition(AnyTransition.opacity.animation(.easeInOut(duration: 3.0)))
    }
}

// MARK: - Previews

#Preview() {
    ZoomableImageView(url: URL(string: "https://picsum.photos/800/1600")!)
}
