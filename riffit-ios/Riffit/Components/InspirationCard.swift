import SwiftUI

/// Reusable card component for displaying an inspiration video
/// in the library feed. Shows platform label, video URL/title,
/// user note, and alignment badge with score.
///
/// Handles all video states:
/// - pending: shows "Waiting to analyze" status
/// - analyzing: shows progress indicator
/// - analyzed: shows full alignment badge + score
/// - archived: dimmed appearance
struct InspirationCard: View {
    let video: InspirationVideo

    var body: some View {
        VStack(alignment: .leading, spacing: .smPlus) {
            // Top row: platform label
            platformLabel

            // Video URL (truncated to show domain)
            Text(displayTitle)
                .riffitHeading()
                .foregroundStyle(Color.riffitTextPrimary)
                .lineLimit(2)

            // User note (if present)
            if let note = video.userNote, !note.isEmpty {
                Text(note)
                    .riffitCaption()
                    .foregroundStyle(Color.riffitTextSecondary)
                    .lineLimit(2)
            }

            // Footer: status or alignment info
            footerContent
        }
        .padding(.md)
        .background(Color.riffitSurface)
        .cornerRadius(.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: .cardRadius)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
        .opacity(video.status == .archived ? 0.5 : 1.0)
    }

    // MARK: - Platform Label

    private var platformLabel: some View {
        HStack(spacing: 6) {
            // Teal dot indicator
            Circle()
                .fill(Color.riffitTeal400)
                .frame(width: 6, height: 6)

            Text(video.platform.displayLabel)
                .riffitLabel()
                .foregroundStyle(Color.riffitTextTertiary)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerContent: some View {
        switch video.status {
        case .pending:
            StatusTag(text: "Waiting to analyze", color: Color.riffitTextTertiary)

        case .analyzing:
            HStack(spacing: .sm) {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.riffitPrimary)
                Text("Analyzing...")
                    .riffitCaption()
                    .foregroundStyle(Color.riffitTextSecondary)
            }

        case .analyzed:
            HStack {
                if let verdict = video.alignmentVerdict {
                    AlignmentBadge(verdict: verdict)
                }
                Spacer()
                if let score = video.alignmentScore {
                    Text("\(score)")
                        .font(.riffitDisplay(24))
                        .foregroundStyle(Color.riffitPrimary)
                }
            }

        case .archived:
            StatusTag(text: "Archived", color: Color.riffitTextTertiary)
        }
    }

    // MARK: - Display Title

    /// Extracts a readable title from the URL.
    /// Shows the domain + path, not the full URL.
    private var displayTitle: String {
        guard let url = URL(string: video.url),
              let host = url.host else {
            return video.url
        }
        // Remove "www." prefix for cleaner display
        let cleanHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let path = url.path
        if path.isEmpty || path == "/" {
            return cleanHost
        }
        // Truncate long paths
        let truncatedPath = path.count > 40 ? String(path.prefix(40)) + "..." : path
        return cleanHost + truncatedPath
    }
}

// MARK: - Status Tag

/// Small tag for showing non-alignment status (pending, archived).
struct StatusTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .riffitCaption()
            .foregroundStyle(color)
            .padding(.vertical, .xs)
            .padding(.horizontal, .sm)
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
