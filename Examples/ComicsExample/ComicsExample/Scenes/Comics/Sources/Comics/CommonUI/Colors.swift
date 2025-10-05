import SwiftUI

extension Color {
#if os(iOS)
    static let systemRed = Color(uiColor: .systemRed)
    static let systemGreen = Color(uiColor: .systemGreen)
    static let systemBlue = Color(uiColor: .systemBlue)
    static let systemOrange = Color(uiColor: .systemOrange)
    static let systemYellow = Color(uiColor: .systemYellow)
    static let systemPink = Color(uiColor: .systemPink)
    static let systemPurple = Color(uiColor: .systemPurple)
    static let systemTeal = Color(uiColor: .systemTeal)
    static let systemIndigo = Color(uiColor: .systemIndigo)
    static let systemBrown = Color(uiColor: .systemBrown)
    static let systemMint = Color(uiColor: .systemMint)
    static let systemCyan = Color(uiColor: .systemCyan)
    static let systemGray = Color(uiColor: .systemGray)
    static let systemGray2 = Color(uiColor: .systemGray2)
    static let systemGray3 = Color(uiColor: .systemGray3)
    static let systemGray4 = Color(uiColor: .systemGray4)
    static let systemGray5 = Color(uiColor: .systemGray5)
    static let systemGray6 = Color(uiColor: .systemGray6)
    static let tintColor = Color(uiColor: .tintColor)
    static let label = Color(uiColor: .label)
    static let secondaryLabel = Color(uiColor: .secondaryLabel)
    static let tertiaryLabel = Color(uiColor: .tertiaryLabel)
    static let quaternaryLabel = Color(uiColor: .quaternaryLabel)
    static let link = Color(uiColor: .link)
    static let placeholderText = Color(uiColor: .placeholderText)
    static let separator = Color(uiColor: .separator)
    static let opaqueSeparator = Color(uiColor: .opaqueSeparator)
    static let systemBackground = Color(uiColor: .systemBackground)
    static let secondarySystemBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiarySystemBackground = Color(uiColor: .tertiarySystemBackground)
    static let systemGroupedBackground = Color(uiColor: .systemGroupedBackground)
    static let secondarySystemGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let tertiarySystemGroupedBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    static let systemFill = Color(uiColor: .systemFill)
    static let secondarySystemFill = Color(uiColor: .secondarySystemFill)
    static let tertiarySystemFill = Color(uiColor: .tertiarySystemFill)
    static let quaternarySystemFill = Color(uiColor: .quaternarySystemFill)
    static let lightText = Color(uiColor: .lightText)
    static let darkText = Color(uiColor: .darkText)
#elseif os(macOS)
    static let systemRed = Color(nsColor: .systemRed)
    static let systemGreen = Color(nsColor: .systemGreen)
    static let systemBlue = Color(nsColor: .systemBlue)
    static let systemOrange = Color(nsColor: .systemOrange)
    static let systemYellow = Color(nsColor: .systemYellow)
    static let systemPink = Color(nsColor: .systemPink)
    static let systemPurple = Color(nsColor: .systemPurple)
    static let systemTeal = Color(nsColor: .systemTeal)
    static let systemIndigo = Color(nsColor: .systemIndigo)
    static let systemBrown = Color(nsColor: .systemBrown)
    static let systemMint = Color(nsColor: .systemMint)
    static let systemCyan = Color(nsColor: .systemCyan)

    // Helper to create dynamic NSColors that switch for light/dark appearances on macOS
    private static func dynamicNSColor(light: NSColor, dark: NSColor) -> NSColor {
        return NSColor(name: nil, dynamicProvider: { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            return match == .darkAqua ? dark : light
        })
    }

    static let systemGray = Color(nsColor: .systemGray)
    static let systemGray2 = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 0.68, alpha: 1.0),
                                                           dark:  NSColor(calibratedWhite: 0.39, alpha: 1.0)))
    static let systemGray3 = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 0.78, alpha: 1.0),
                                                           dark:  NSColor(calibratedWhite: 0.31, alpha: 1.0)))
    static let systemGray4 = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 0.87, alpha: 1.0),
                                                           dark:  NSColor(calibratedWhite: 0.24, alpha: 1.0)))
    static let systemGray5 = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 0.92, alpha: 1.0),
                                                           dark:  NSColor(calibratedWhite: 0.18, alpha: 1.0)))
    static let systemGray6 = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 0.96, alpha: 1.0),
                                                           dark:  NSColor(calibratedWhite: 0.10, alpha: 1.0)))

    static let tintColor = Color(nsColor: .controlAccentColor)
    static let label = Color(nsColor: .labelColor)
    static let secondaryLabel = Color(nsColor: .secondaryLabelColor)
    static let tertiaryLabel = Color(nsColor: .tertiaryLabelColor)
    static let quaternaryLabel = Color(nsColor: .quaternaryLabelColor)
    static let link = Color(nsColor: .linkColor)
    static let placeholderText = Color(nsColor: .placeholderTextColor)
    static let separator = Color(nsColor: .separatorColor)
    static let opaqueSeparator = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 0.78, alpha: 1.0),
                                                               dark:  NSColor(calibratedWhite: 0.22, alpha: 1.0)))
    static let systemBackground = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 1.00, alpha: 1.0),
                                                                dark:  NSColor(calibratedWhite: 0.12, alpha: 1.0)))
    static let secondarySystemBackground = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 0.95, alpha: 1.0),
                                                                         dark:  NSColor(calibratedWhite: 0.08, alpha: 1.0)))
    static let tertiarySystemBackground = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 0.90, alpha: 1.0),
                                                                        dark:  NSColor(calibratedWhite: 0.05, alpha: 1.0)))

    static let systemGroupedBackground = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 0.95, alpha: 1.0),
                                                                       dark:  NSColor(calibratedWhite: 0.06, alpha: 1.0)))
    static let secondarySystemGroupedBackground = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 0.98, alpha: 1.0),
                                                                               dark:  NSColor(calibratedWhite: 0.09, alpha: 1.0)))
    static let tertiarySystemGroupedBackground = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 1.00, alpha: 1.0),
                                                                              dark:  NSColor(calibratedWhite: 0.12, alpha: 1.0)))

    static let systemFill = Color(nsColor: .systemFill)
    static let secondarySystemFill = Color(nsColor: .secondarySystemFill)
    static let tertiarySystemFill = Color(nsColor: .tertiarySystemFill)
    static let quaternarySystemFill = Color(nsColor: .quaternarySystemFill)

    static let lightText = Color(nsColor: dynamicNSColor(light: NSColor(calibratedWhite: 1.0, alpha: 0.6),
                                                         dark:  NSColor(calibratedWhite: 1.0, alpha: 0.6)))
    static let darkText = Color(nsColor: .textColor)
#endif
}
