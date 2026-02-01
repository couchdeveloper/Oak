import Foundation
import SwiftUI

struct ImageError: LocalizedError {
    let underlyingError: Error?
    let message: String?
    
    init(message: String) {
        underlyingError = nil
        self.message = message
    }
    init(underlyingError: Error) {
        self.message = nil
        self.underlyingError = underlyingError
    }
    
    var errorDescription: String? {
        self.underlyingError?.localizedDescription ?? self.message
    }
}

#if os(iOS)
import UIKit.UIImage
/// Alias for `UIImage`.
public typealias PlatformImage = UIImage
extension PlatformImage {
    public var image: Image {
        Image(uiImage: self)
    }
    
}
#elseif os(macOS)
import AppKit.NSImage
/// Alias for `NSImage`.
    public typealias PlatformImage = NSImage
extension PlatformImage {
    public var image: Image {
        Image(nsImage: self)
    }
}
#endif


extension PlatformImage {
    
    public static func image(from data: Data) throws -> PlatformImage {
        guard let image = PlatformImage(data: data) else {
            throw ImageError(message: "Failed to create UIImage from data")
        }
        return image
    }
}

