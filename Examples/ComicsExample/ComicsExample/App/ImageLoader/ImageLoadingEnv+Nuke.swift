import Comics
import Nuke

extension ImageLoadingEnv {
    static let live: ImageLoadingEnv = .init { url in
        Task {
            let imageTask = ImagePipeline.shared.imageTask(with: url)
            return try await withTaskCancellationHandler {
                try await imageTask.image
            } onCancel: {
                imageTask.cancel()
            }
        }
    }
}
