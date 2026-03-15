import SwiftUI

// MARK: - Color Token Extensions

/// All Riffit design system colors exposed as static properties on Color.
/// These automatically adapt to the current color scheme (dark/light mode)
/// using SwiftUI's adaptive color system.
///
/// Usage: Color.riffitPrimary, Color.riffitBackground, etc.
/// Never hardcode hex values in views — always use these tokens.

extension Color {

    // MARK: Backgrounds

    /// Screen background — dark: #111111, light: #F5F2EB
    static let riffitBackground = Color("RiffitBackground", bundle: nil)

    /// Cards, sheets, rows — dark: #1C1C1C, light: #FFFFFF
    static let riffitSurface = Color("RiffitSurface", bundle: nil)

    /// Modals, popovers, dropdowns — dark: #272727, light: #FFFFFF
    static let riffitElevated = Color("RiffitElevated", bundle: nil)

    // MARK: Borders

    /// Subtle border — dark: white 7%, light: black 6%
    static let riffitBorderSubtle = Color("RiffitBorderSubtle", bundle: nil)

    /// Default border — dark: white 10%, light: black 10%
    static let riffitBorderDefault = Color("RiffitBorderDefault", bundle: nil)

    // MARK: Text

    /// Primary text — dark: #F2F0EB, light: #1A1A1A
    static let riffitTextPrimary = Color("RiffitTextPrimary", bundle: nil)

    /// Secondary text — dark: #888888, light: #888888
    static let riffitTextSecondary = Color("RiffitTextSecondary", bundle: nil)

    /// Tertiary text — dark: #444444, light: #AAAAAA
    static let riffitTextTertiary = Color("RiffitTextTertiary", bundle: nil)

    // MARK: Primary (Sunset Gold)

    /// Primary color — #F0AA20 (sunset gold) — buttons, active states, scores
    static let riffitPrimary = Color(hex: 0xF0AA20)

    /// Primary pressed — #E87820 (amber)
    static let riffitPrimaryPressed = Color(hex: 0xE87820)

    /// Primary tint — sunset gold at 12% opacity (badge backgrounds)
    static let riffitPrimaryTint = Color("RiffitPrimaryTint", bundle: nil)

    /// Primary ghost — sunset gold at 6% opacity (hover, selected rows)
    static let riffitPrimaryGhost = Color("RiffitPrimaryGhost", bundle: nil)

    /// Primary text color for light mode legibility — dark: #F0AA20, light: #C88A00
    static let riffitPrimaryText = Color("RiffitPrimaryText", bundle: nil)

    // MARK: Teal

    /// Teal 900 — #0A4A52 (darkest, structural)
    static let riffitTeal900 = Color(hex: 0x0A4A52)

    /// Teal 600 — #0F6B75 (secondary actions, info)
    static let riffitTeal600 = Color(hex: 0x0F6B75)

    /// Teal 400 — #1A8A96 (links, interactive hints)
    static let riffitTeal400 = Color(hex: 0x1A8A96)

    /// Teal tint — teal at ~15% dark / ~8% light (storybank badges)
    static let riffitTealTint = Color("RiffitTealTint", bundle: nil)

    // MARK: Danger (Coral Burn)

    /// Danger color — dark: #D94E2A, light: #C03D1E
    static let riffitDanger = Color("RiffitDanger", bundle: nil)

    /// Danger tint — danger at ~12% dark / ~8% light
    static let riffitDangerTint = Color("RiffitDangerTint", bundle: nil)

    // MARK: Grid Background (empty states)

    /// Grid background — light: #F0EBD8 (warm beige), dark: #111111 (matches screen bg)
    static let riffitGridBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x11/255.0, green: 0x11/255.0, blue: 0x11/255.0, alpha: 1)
            : UIColor(red: 0xF0/255.0, green: 0xEB/255.0, blue: 0xD8/255.0, alpha: 1)
    })

    /// Grid line color — light: #D8D0BC, dark: white at 4% opacity
    static let riffitGridLine = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.04)
            : UIColor(red: 0xD8/255.0, green: 0xD0/255.0, blue: 0xBC/255.0, alpha: 1)
    })

    // MARK: On Primary

    /// Text color on primary (gold) buttons — always #111111
    /// Gold fill needs dark text in both light and dark mode.
    static let riffitOnPrimary = Color(hex: 0x111111)
}

// MARK: - Hex Color Initializer

extension Color {
    /// Creates a Color from a hex integer value.
    /// Example: Color(hex: 0xF0AA20)
    init(hex: UInt, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - Corner Radius Constants

extension CGFloat {
    /// Tag/chip corner radius — 6pt
    static let tagRadius: CGFloat = 6

    /// Button corner radius — 10pt
    static let buttonRadius: CGFloat = 10

    /// Input/row corner radius — 14pt
    static let inputRadius: CGFloat = 14

    /// Card corner radius — 20pt
    static let cardRadius: CGFloat = 20

    /// Sheet corner radius (top corners only) — 20pt
    static let sheetRadius: CGFloat = 20
}
