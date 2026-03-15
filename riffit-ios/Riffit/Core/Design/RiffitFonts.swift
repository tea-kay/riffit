import SwiftUI

// MARK: - Font Statics

/// Riffit design system fonts.
/// Lora — all headings, titles, buttons, labels, tags.
/// DM Sans — body text, metadata, timestamps, URLs, captions.
/// Georgia Bold Italic is used ONLY in RiffitWordmark (the splash logo).

extension Font {

    // MARK: Lora (Headings / UI Chrome)

    /// Lora at a custom size, with optional italic and weight control.
    /// - Regular (400), Medium (500), Bold (700), Italic (400-italic)
    static func riffitSerif(
        _ size: CGFloat,
        italic: Bool = false,
        weight: Font.Weight = .regular
    ) -> Font {
        switch (italic, weight) {
        case (true, _):    return .custom("Lora-Italic", size: size)
        case (_, .bold):   return .custom("Lora-Bold", size: size)
        case (_, .medium): return .custom("Lora-Medium", size: size)
        default:           return .custom("Lora-Regular", size: size)
        }
    }

    /// 32pt Lora Bold — hero text, display headings
    static var riffitLargeTitle: Font { riffitSerif(32, weight: .bold) }

    /// 24pt Lora Bold — page titles (Ideas, Storybank, Settings)
    static var riffitTitle: Font { riffitSerif(24, weight: .bold) }

    /// 20pt Lora Bold — card titles, section headings, empty state headlines
    static var riffitHeading: Font { riffitSerif(20, weight: .bold) }

    /// 16pt Lora Medium — button text (all variants)
    static var riffitButton: Font { riffitSerif(16, weight: .medium) }

    /// 13pt Lora Medium — section labels (NOTES, MY ASSETS, etc.)
    static var riffitLabel: Font { riffitSerif(13, weight: .medium) }

    /// 12pt Lora Medium — tag/badge text, status pills
    static var riffitTag: Font { riffitSerif(12, weight: .medium) }

    /// 12pt Lora Italic — italic tag variant
    static var riffitTagItalic: Font { riffitSerif(12, italic: true) }

    // MARK: DM Sans (Body / Metadata)

    /// DM Sans at a custom size and weight.
    static func riffitSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .medium: return .custom("DMSans-Medium", size: size)
        case .light:  return .custom("DMSans-Light", size: size)
        default:      return .custom("DMSans-Regular", size: size)
        }
    }

    /// 16pt DM Sans Regular — body descriptions, form inputs, chat text
    static var riffitBody: Font { .riffitSans(16) }

    /// 12pt DM Sans Regular — captions, secondary info, subtext
    static var riffitCaption: Font { .riffitSans(12) }

    /// 11pt DM Sans Regular — timestamps, metadata counts
    static var riffitMeta: Font { .riffitSans(11) }

    /// 12pt DM Sans Light — URL text, links
    static var riffitURL: Font { .riffitSans(12, weight: .light) }
}

// MARK: - View Modifier Helpers

/// Convenience modifiers that apply the font tokens.
/// These keep existing call sites like `.riffitBody()` working
/// while routing to the new Lora / DM Sans fonts.

extension View {

    /// Display/hero text — Lora Bold 32pt
    func riffitDisplay() -> some View {
        self.font(.riffitLargeTitle)
    }

    /// Page title — Lora Bold 24pt
    func riffitPageTitle() -> some View {
        self.font(.riffitTitle)
    }

    /// Title — Lora Bold 24pt
    func riffitTitle() -> some View {
        self.font(.riffitTitle)
    }

    /// Heading — Lora Bold 20pt
    func riffitHeading() -> some View {
        self.font(.riffitHeading)
    }

    /// Body text — DM Sans 16pt
    func riffitBody() -> some View {
        self.font(.riffitBody)
    }

    /// Callout — maps to DM Sans 16pt (same as body)
    func riffitCallout() -> some View {
        self.font(.riffitBody)
    }

    /// Subhead — maps to DM Sans 16pt
    func riffitSubhead() -> some View {
        self.font(.riffitBody)
    }

    /// Caption — DM Sans 12pt
    func riffitCaption() -> some View {
        self.font(.riffitCaption)
    }

    /// Label — Lora Medium 13pt, uppercase, letter-spaced 0.08em
    func riffitLabel() -> some View {
        self
            .font(.riffitLabel)
            .textCase(.uppercase)
            .tracking(0.08 * 13)
    }

    /// Primary button font — Lora Medium 16pt
    func riffitPrimaryButtonFont() -> some View {
        self.font(.riffitButton)
    }

    /// Brand tagline — DM Sans Light 13pt, letter-spaced
    func riffitTagline() -> some View {
        self
            .font(.riffitSans(13, weight: .light))
            .kerning(1.0)
    }
}

// MARK: - TextField Modifier

/// Canonical modifier for all custom TextFields — applies DM Sans 16pt
/// so placeholders and typed text use the Riffit body font.
struct RiffitTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.riffitBody)
    }
}
