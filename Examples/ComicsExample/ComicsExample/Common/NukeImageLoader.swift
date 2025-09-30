import Nuke

struct NukeImageLoader: ImageLoader {

    private let imagePipeline: ImagePipeline

    static var `default`: ImageLoader = NukeImageLoader(imagePipeline: ImagePipeline.shared)

    func load(string: URLReference) throws -> Common.PlatformImage {
        guard let url = URL(string: string.absoluteString) else {
            fatalError("Invalid URL: \(string)")
        }
        let imageTask = ImagePipeline.shared.imageTask(with: url)
        for await progress in imageTask.progress {
            // Update progress
        }
        return try await imageTask.image
    }

}
