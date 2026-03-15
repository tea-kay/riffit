import SwiftUI

// MARK: - Font Statics

/// Riffit design system fonts.
/// Abril Fatface — all headings, titles, buttons, labels, tags.
/// DM Sans — body text, metadata, timestamps, URLs, captions.
/// Georgia Bold Italic is used ONLY in RiffitWordmark (the splash logo).

extension Font {

    // MARK: Abril Fatface (Headings)

    /// Abril Fatface at a custom size — for any heading that doesn't
    /// fit the preset tokens (e.g. alignment scores).
    static func riffitDisplay(_ size: CGFloat) -> Font {
        .custom("AbrilFatface-Regular", size: size)
    }

    /// 32pt — hero text, display headings
    static var riffitLargeTitle: Font { .riffitDisplay(32) }

    /// 24pt — page titles (Ideas, Storybank, Settings)
    static var riffitTitle: Font { .riffitDisplay(24) }

    /// 20pt — card titles, section headings, empty state headlines
    static var riffitHeading: Font { .riffitDisplay(20) }

    /// 16pt — button text (all variants)
    static var riffitButton: Font { .riffitDisplay(16) }

    /// 13pt — section labels (NOTES, MY ASSETS, etc.)
    static var riffitLabel: Font { .riffitDisplay(13) }

    /// 11pt — tag/badge text, status pills
    static var riffitTag: Font { .riffitDisplay(11) }

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
/// while routing to the new Abril Fatface / DM Sans fonts.

extension View {

    /// Display/hero text — Abril Fatface 32pt
    func riffitDisplay() -> some View {
        self.font(.riffitLargeTitle)
    }

    /// Page title — Abril Fatface 24pt
    func riffitPageTitle() -> some View {
        self.font(.riffitTitle)
    }

    /// Title — Abril Fatface 24pt
    func riffitTitle() -> some View {
        self.font(.riffitTitle)
    }

    /// Heading — Abril Fatface 20pt
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

    /// Label — Abril Fatface 13pt, uppercase, letter-spaced 0.08em
    func riffitLabel() -> some View {
        self
            .font(.riffitLabel)
            .textCase(.uppercase)
            .tracking(0.08 * 13)
    }

    /// Primary button font — Abril Fatface 16pt
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
