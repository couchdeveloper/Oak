import Foundation
import SwiftUI

#if os(iOS)
import UIKit.UIImage
/// Alias for `UIImage`.
extension Common {
    public typealias PlatformImage = UIImage
}
extension Common.PlatformImage {
    var image: Image {
        Image(uiImage: self)
    }
}
#elseif os(macOS)
import AppKit.NSImage
/// Alias for `NSImage`.
extension Common {
    public typealias PlatformImage = NSImage
}
extension Common.PlatformImage {
    var image: Image {
        Image(nsImage: self)
    }
}
#endif

