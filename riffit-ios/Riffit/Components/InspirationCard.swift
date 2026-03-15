import SwiftUI

/// Reusable card component for displaying an inspiration video.
/// Layout (top to bottom):
///   1. Platform label with teal dot
///   2. Auto-generated summary (heading, 2 lines) — shimmer while analyzing
///   3. Tag pills
///   4. "Your take:" + user note (1 line)
///   5. Stats row + alignment score
struct InspirationCard: View {
    let video: InspirationVideo
    var tags: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: RS.smPlus) {
            // Platform label
            platformLabel

            // Auto-generated summary or shimmer placeholder
            summarySection

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

            // Footer: stats + alignment
            footerContent
        }
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

    // MARK: - Summary

    @ViewBuilder
    private var summarySection: some View {
        if let summary = video.summary, !summary.isEmpty {
            Text(summary)
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)
                .lineLimit(2)
                .truncationMode(.tail)
        } else if video.status == .pending || video.status == .analyzing {
            // Shimmer placeholder while summary is being generated
            VStack(alignment: .leading, spacing: 6) {
                ShimmerBlock()
                    .frame(height: 18)
                ShimmerBlock()
                    .frame(width: 180, height: 18)
            }
        } else {
            // Analyzed but no summary — show URL as fallback title
            Text(displayTitle)
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)
                .lineLimit(2)
        }
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

    // MARK: - Footer

    @ViewBuilder
    private var footerContent: some View {
        switch video.status {
        case .pending:
            HStack {
                statsRow
                Spacer()
                StatusTag(text: "Waiting to analyze", color: Color.riffitTextTertiary)
            }

        case .analyzing:
            HStack {
                statsRow
                Spacer()
                HStack(spacing: RS.sm) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.riffitPrimary)
                    Text("Analyzing...")
                        .font(RF.caption)
                        .foregroundStyle(Color.riffitTextSecondary)
                }
            }

        case .analyzed:
            HStack {
                statsRow

                Spacer()

                if let verdict = video.alignmentVerdict {
                    AlignmentBadge(verdict: verdict)
                }

                if let score = video.alignmentScore {
                    Text("\(score)/100")
                        .font(RF.label)
                        .foregroundStyle(Color.riffitPrimary)
                }
            }

        case .archived:
            HStack {
                statsRow
                Spacer()
                StatusTag(text: "Archived", color: Color.riffitTextTertiary)
            }
        }
    }

    // MARK: - Stats Row

    @ViewBuilder
    private var statsRow: some View {
        let hasStats = video.viewCount != nil || video.likeCount != nil || video.commentCount != nil

        if hasStats {
            HStack(spacing: RS.smPlus) {
                if let views = video.viewCount {
                    Text("\u{1F441} \(formatStat(views))")
                        .font(RF.meta)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
                if let likes = video.likeCount {
                    Text("\u{2764}\u{FE0F} \(formatStat(likes))")
                        .font(RF.meta)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
                if let comments = video.commentCount {
                    Text("\u{1F4AC} \(formatStat(comments))")
                        .font(RF.meta)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
            }
        }
    }

    // MARK: - Display Title (fallback)

    private var displayTitle: String {
        guard let url = URL(string: video.url),
              let host = url.host else {
            return video.url
        }
        let cleanHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let path = url.path
        if path.isEmpty || path == "/" {
            return cleanHost
        }
        let truncatedPath = path.count > 40 ? String(path.prefix(40)) + "..." : path
        return cleanHost + truncatedPath
    }
}

// MARK: - Shimmer Block

/// Pulsing placeholder for content that's still loading.
struct ShimmerBlock: View {
    @State private var opacity: Double = 0.12

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.riffitTextTertiary.opacity(opacity))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    opacity = 0.25
                }
            }
    }
}

// MARK: - Status Tag

/// Small tag for showing non-alignment status (pending, archived).
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

// MARK: - Stat Formatter

/// Abbreviates large numbers for display: 2300000 → "2.3M", 48000 → "48K".
func formatStat(_ n: Int) -> String {
    if n >= 1_000_000 {
        let m = Double(n) / 1_000_000.0
        let formatted = String(format: "%.1f", m)
        return formatted.hasSuffix(".0")
            ? "\(n / 1_000_000)M"
            : "\(formatted)M"
    }
    if n >= 1_000 {
        let k = Double(n) / 1_000.0
        let formatted = String(format: "%.1f", k)
        return formatted.hasSuffix(".0")
            ? "\(n / 1_000)K"
            : "\(formatted)K"
    }
    return "\(n)"
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
