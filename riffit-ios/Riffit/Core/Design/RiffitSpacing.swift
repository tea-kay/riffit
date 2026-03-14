import SwiftUI

// MARK: - Spacing Constants (4pt grid)

/// Spacing constants following a 4pt grid system.
/// Used throughout the app for consistent padding and layout.
///
/// Usage: .padding(.md), spacing: .lg, etc.
extension CGFloat {
    /// Extra small spacing — 4pt
    static let xs: CGFloat = 4

    /// Small spacing — 8pt
    static let sm: CGFloat = 8

    /// Small-plus spacing — 12pt
    static let smPlus: CGFloat = 12

    /// Medium spacing — 16pt
    static let md: CGFloat = 16

    /// Large spacing — 24pt
    static let lg: CGFloat = 24

    /// Extra large spacing — 32pt
    static let xl: CGFloat = 32

    /// 2x extra large spacing — 40pt
    static let xl2: CGFloat = 40

    /// 3x extra large spacing — 56pt
    static let xl3: CGFloat = 56
}
