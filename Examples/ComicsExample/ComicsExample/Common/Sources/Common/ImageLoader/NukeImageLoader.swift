import Nuke
import Foundation

enum NukeImageLoader: ImageLoader {

    static func load(url: URLReference) async throws -> Common.PlatformImage {
        guard let url = URL(string: url) else {
            fatalError("Invalid URL: \(url)")
        }
        let imageTask = ImagePipeline.shared.imageTask(with: url)
        // for await progress in imageTask.progress {
        //     // Update progress
        // }
        return try await imageTask.image
    }

}
