import SwiftUI

/// Single source of truth for ALL design tokens.
/// One change here = the whole app updates.
struct RiffitTheme {

    // ── Typography ──────────────────────────────
    struct Fonts {
        // Font family names — change these strings to swap fonts app-wide
        static let displayName      = "Lora-Bold"
        static let displayMedName   = "Lora-Medium"
        static let displayRegName   = "Lora-Regular"
        static let displayItalicName = "Lora-Italic"
        static let bodyName         = "DMSans-Regular"
        static let bodyMediumName   = "DMSans-Medium"
        static let bodyLightName    = "DMSans-Light"

        // Factory methods
        static func display(_ size: CGFloat) -> Font {
            .custom(displayName, size: size)
        }
        static func displayMedium(_ size: CGFloat) -> Font {
            .custom(displayMedName, size: size)
        }
        static func displayItalic(_ size: CGFloat) -> Font {
            .custom(displayItalicName, size: size)
        }
        static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            switch weight {
            case .medium: return .custom(bodyMediumName, size: size)
            case .light:  return .custom(bodyLightName, size: size)
            default:      return .custom(bodyName, size: size)
            }
        }

        // Named scale — use these everywhere
        static var largeTitle: Font { display(32) }
        static var title: Font      { display(24) }
        static var heading: Font    { display(20) }
        static var button: Font     { displayMedium(16) }
        static var label: Font      { displayMedium(13) }
        static var tag: Font        { displayMedium(12) }
        static var tagItalic: Font  { displayItalic(12) }
        static var bodyLg: Font     { body(17) }
        static var bodyMd: Font     { body(15) }
        static var bodySm: Font     { body(13) }
        static var caption: Font    { body(12) }
        static var meta: Font       { body(11) }
        static var url: Font        { body(12, weight: .light) }
    }

    // ── Spacing (4pt grid) ──────────────────────
    struct Spacing {
        static let xs: CGFloat   = 4
        static let sm: CGFloat   = 8
        static let smPlus: CGFloat = 12
        static let md: CGFloat   = 16
        static let lg: CGFloat   = 24
        static let xl: CGFloat   = 32
        static let xl2: CGFloat  = 40
        static let xl3: CGFloat  = 56
    }

    // ── Radius ──────────────────────────────────
    struct Radius {
        static let tag: CGFloat    = 6
        static let button: CGFloat = 10
        static let input: CGFloat  = 14
        static let card: CGFloat   = 20
        static let modal: CGFloat  = 24
    }
}

// Convenience typealiases — short, readable, everywhere
typealias RF = RiffitTheme.Fonts
typealias RS = RiffitTheme.Spacing
typealias RR = RiffitTheme.Radius
