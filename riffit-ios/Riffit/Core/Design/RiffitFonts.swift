import SwiftUI

// MARK: - Typography Helpers

/// Typography modifiers matching the Riffit design system.
/// Brand text (display, page titles, tagline, primary buttons) uses Georgia italic.
/// UI text (headings, body, captions, labels) uses SF Pro.
///
/// Usage: Text("Hello").riffitDisplay()
/// These modifiers set font, weight, and any extra tracking.

extension View {
    /// Display/hero text — Georgia Bold Italic, 32pt
    /// Used for the app wordmark and splash headlines.
    func riffitDisplay() -> some View {
        self
            .font(.custom("Georgia-BoldItalic", size: 32))
    }

    /// Page title — Georgia Bold Italic, 26pt
    /// Used for top-level screen titles: Ideas, Storybank, Settings.
    func riffitPageTitle() -> some View {
        self
            .font(.custom("Georgia-BoldItalic", size: 26))
    }

    /// Title style — 22pt, medium weight (maps to .title)
    func riffitTitle() -> some View {
        self
            .font(.title)
            .fontWeight(.medium)
    }

    /// Tagline — Georgia Italic, 13pt, with 1pt letter spacing
    /// Used for "scroll, riff, post" and similar brand taglines.
    func riffitTagline() -> some View {
        self
            .font(.custom("Georgia-Italic", size: 13))
            .kerning(1.0)
    }

    /// Primary button text — Georgia Bold Italic, 15pt
    /// Used on primary (gold) buttons.
    func riffitPrimaryButtonFont() -> some View {
        self
            .font(.custom("Georgia-BoldItalic", size: 15))
    }

    /// Heading style — 17pt, medium weight (maps to .headline)
    func riffitHeading() -> some View {
        self
            .font(.headline)
            .fontWeight(.medium)
    }

    /// Body style — 17pt, regular weight (maps to .body)
    func riffitBody() -> some View {
        self
            .font(.body)
    }

    /// Callout style — 16pt, regular weight (maps to .callout)
    func riffitCallout() -> some View {
        self
            .font(.callout)
    }

    /// Subhead style — 15pt, regular weight (maps to .subheadline)
    func riffitSubhead() -> some View {
        self
            .font(.subheadline)
    }

    /// Caption style — 12pt, regular weight (maps to .caption)
    func riffitCaption() -> some View {
        self
            .font(.caption)
    }

    /// Label style — 11pt, medium weight, uppercase, tracked (maps to .caption2)
    /// Used for small labels like platform tags, status indicators, etc.
    func riffitLabel() -> some View {
        self
            .font(.caption2)
            .fontWeight(.medium)
            .textCase(.uppercase)
            .tracking(0.06 * 11)  // 0.06em at 11pt
    }
}
