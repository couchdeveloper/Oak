import Foundation
import SwiftUI

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

