import SwiftUI

/// Reusable card component for displaying an inspiration video.
/// Layout (top to bottom):
///   1. Platform label with teal dot
///   2. Title (from metadata, user note, or platform fallback)
///   3. Tag pills
///   4. "Your take:" + user note (1 line)
struct InspirationCard: View {
    let video: InspirationVideo
    var tags: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: RS.smPlus) {
            // Platform label
            platformLabel

            // Title
            titleSection

            // Tag pills
            if !tags.isEmpty {
                tagsRow
            }

            // User note
            if let note = video.userNote, !note.isEmpty {
                HStack(spacing: 4) {
                    Text("Your take:")
                        .font(RF.caption)
                        .foregroundStyle(Color.riffitTextTertiary)
                    Text(note)
                        .font(RF.caption)
                        .foregroundStyle(Color.riffitTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            // Archived tag if applicable
            if video.status == .archived {
                StatusTag(text: "Archived", color: Color.riffitTextTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RS.md)
        .background(Color.riffitSurface)
        .cornerRadius(RR.card)
        .overlay(
            RoundedRectangle(cornerRadius: RR.card)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
        .opacity(video.status == .archived ? 0.5 : 1.0)
    }

    // MARK: - Platform Label

    private var platformLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.riffitTeal400)
                .frame(width: 6, height: 6)

            Text(video.platform.displayLabel)
                .font(RF.tag)
                .textCase(.uppercase)
                .tracking(0.08 * 12)
                .foregroundStyle(Color.riffitTextTertiary)
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        Text(cardTitle)
            .font(RF.heading)
            .foregroundStyle(Color.riffitTextPrimary)
            .lineLimit(2)
            .truncationMode(.tail)
    }

    /// Title hierarchy:
    /// 1. video.title (from og:title or manual entry)
    /// 2. First 8 words of video.userNote
    /// 3. Platform name + "reel" as last resort
    private var cardTitle: String {
        // 1. Explicit title from metadata or manual entry
        if let title = video.title, !title.isEmpty {
            return title
        }

        // 2. First 8 words of the user note
        if let note = video.userNote, !note.isEmpty {
            let words = note.split(separator: " ", omittingEmptySubsequences: true)
            if words.count <= 8 {
                return note
            }
            return words.prefix(8).joined(separator: " ") + "..."
        }

        // 3. Platform + "reel" fallback
        return video.platform.displayLabel + " reel"
    }

    // MARK: - Tags

    private var tagsRow: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(RF.tag)
                    .foregroundStyle(Color.riffitPrimary)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color.riffitPrimaryTint)
                    .clipShape(Capsule())
            }
        }
    }

}

// MARK: - Status Tag

/// Small tag for showing video status (archived).
struct StatusTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(RF.caption)
            .foregroundStyle(color)
            .padding(.vertical, RS.xs)
            .padding(.horizontal, RS.sm)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Platform Display Label

extension InspirationVideo.Platform {
    /// Human-readable label for the platform.
    var displayLabel: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .youtube: return "YouTube"
        case .linkedin: return "LinkedIn"
        case .x: return "X"
        }
    }
}
