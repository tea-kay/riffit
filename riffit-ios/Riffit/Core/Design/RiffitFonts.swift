import SwiftUI

// MARK: - Typography Helpers

/// Typography modifiers matching the Riffit design system.
/// All use SF Pro (the iOS system font — no import needed).
///
/// Usage: Text("Hello").riffitDisplay()
/// These modifiers set font, weight, and any extra tracking.

extension View {
    /// Display style — 32pt, medium weight (maps to .largeTitle)
    func riffitDisplay() -> some View {
        self
            .font(.largeTitle)
            .fontWeight(.medium)
    }

    /// Title style — 22pt, medium weight (maps to .title)
    func riffitTitle() -> some View {
        self
            .font(.title)
            .fontWeight(.medium)
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
