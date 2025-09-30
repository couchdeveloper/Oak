import Foundation

#if !os(macOS)
import UIKit.UIImage
/// Alias for `UIImage`.
extension Common {
    public typealias PlatformImage = UIImage
}
#else
import AppKit.NSImage
/// Alias for `NSImage`.
extension Commom {
    public typealias PlatformImage = NSImage
}
#endif

