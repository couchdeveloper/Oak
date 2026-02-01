import SwiftUI
import Oak
import Common

// MARK: - Image Loading IoC Port
// Note: Currently, this is only used in ZoomableImageView. We may consider to
// move the IoC port to a separate file when it will be used by other views as
// well.
public struct ImageLoadingEnv: Sendable{
    public var start: @Sendable (_ url: URL) -> Task<PlatformImage, Error>
    public init(start: @escaping @Sendable (_ url: URL) -> Task<PlatformImage, Error>) {
        self.start = start
    }
}

extension EnvironmentValues {
    @Entry public var imageLoading: ImageLoadingEnv = .mock
}

// MARK: - Internal View

struct ZoomableImageView: View {
    @Environment(\.imageLoading) private var imageLoading
    let url: URL

    @State private var scale: CGFloat = 1.0
    @State private var imageState: ImageState = .start

    enum ImageState {
        case start
        case loading(task: Task<PlatformImage, Error>)
        case cancelled
        case completed(Result<PlatformImage, Swift.Error>)
        
        func cancel() {
            if case .loading(let task) = self {
                task.cancel()
            }
        }
    }
    
    var body: some View {
        ZStack {
            switch imageState {
            case .start:
                Color.clear
            
            case .loading:
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
                            #if DEBUG
                            print("scale: \(value)")
                            #endif
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
            let task = imageLoading.start(url)
            imageState = .loading(task: task)
            do {
                let image = try await task.value
                self.imageState = .completed(.success(image))
            } catch is CancellationError {
                self.imageState = .cancelled
            } catch {
                self.imageState = .completed(.failure(error))
            }
        }
        .onDisappear {
            imageState.cancel()
        }
        .transition(AnyTransition.opacity.animation(.easeInOut(duration: 3.0)))
    }
}

// MARK: - Previews

#if DEBUG

fileprivate extension ImageLoadingEnv {
    static let mock: ImageLoadingEnv = .init { url in
        Task {
            let request = URLRequest(url: url)
            let (data, repsonse) = try await URLSession.shared.data(for: request)
            let httpResponse = repsonse as? HTTPURLResponse
            switch (data, httpResponse) {
            case (let data, .some(let httpResponse)) where (200..<300).contains(httpResponse.statusCode):
                let image = try PlatformImage.image(from: data)
                return image
                
            default:
                throw URLError(.badServerResponse)
            }
        }
    }
}


#Preview() {
    ZoomableImageView(url: URL(string: "https://picsum.photos/800/1600")!)
        .environment(\.imageLoading, .mock)
}

#endif
