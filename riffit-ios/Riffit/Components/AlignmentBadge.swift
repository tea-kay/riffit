import SwiftUI

/// Capsule-shaped badge showing the alignment verdict for a video.
/// Three states: strong (primary tint), consider (surface), skip (danger tint).
/// Never used for anything other than alignment verdict display.
struct AlignmentBadge: View {
    let verdict: InspirationVideo.AlignmentVerdict

    var body: some View {
        Text(verdict.label)
            .font(.caption2)
            .fontWeight(.medium)
            .textCase(.uppercase)
            .tracking(0.06 * 11)  // 0.06em at 11pt (caption2 size)
            .padding(.vertical, .xs)
            .padding(.horizontal, 10)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch verdict {
        case .strong:
            return Color.riffitPrimaryTint
        case .consider:
            return Color.riffitSurface
        case .skip:
            return Color.riffitDangerTint
        }
    }

    private var foregroundColor: Color {
        switch verdict {
        case .strong:
            return Color.riffitPrimary
        case .consider:
            return Color.riffitTextSecondary
        case .skip:
            return Color.riffitDanger
        }
    }
}

extension InspirationVideo.AlignmentVerdict {
    /// Human-readable label for the verdict badge.
    var label: String {
        switch self {
        case .strong: return "Strong"
        case .consider: return "Consider"
        case .skip: return "Skip"
        }
    }
}
