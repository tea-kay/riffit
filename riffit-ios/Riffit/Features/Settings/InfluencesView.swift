import SwiftUI

/// Shows which inspiration videos the creator references most often
/// across all their stories. Computed entirely from local state.
struct InfluencesView: View {
    @EnvironmentObject var storybankViewModel: StorybankViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel

    @State private var animateProgress: Bool = false

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            if allReferences.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: RS.lg) {
                        summaryStrip

                        influencesSection("Most Referenced") {
                            ForEach(Array(videoReferenceCounts.enumerated()), id: \.element.video.id) { index, entry in
                                videoRow(rank: index + 1, video: entry.video, count: entry.count)
                            }
                        }

                        if !tagBreakdown.isEmpty {
                            influencesSection("What You Reference") {
                                ForEach(tagBreakdown, id: \.tag) { entry in
                                    tagRow(tag: entry.tag, count: entry.count, percentage: entry.percentage)
                                }
                            }
                        }

                        if let dominant = dominantTag,
                           let topPercentage = tagBreakdown.first?.percentage,
                           topPercentage >= 30 {
                            patternCard(dominantTag: dominant)
                        }

                        Color.clear.frame(height: RS.lg)
                    }
                    .padding(.horizontal, RS.md)
                    .padding(.top, RS.smPlus)
                }
            }
        }
        .navigationTitle("Your influences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Your influences")
                    .font(RF.title)
                    .foregroundStyle(Color.riffitTextPrimary)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateProgress = true
            }
        }
    }

    // MARK: - Computed Data

    private var allReferences: [StoryReference] {
        storybankViewModel.storyReferencesMap.values.flatMap { $0 }
    }

    private var totalReferenceCount: Int {
        allReferences.count
    }

    private var uniqueVideoCount: Int {
        Set(allReferences.map(\.inspirationVideoId)).count
    }

    private var videoReferenceCounts: [(video: InspirationVideo, count: Int)] {
        let grouped = Dictionary(grouping: allReferences, by: \.inspirationVideoId)
        var results: [(video: InspirationVideo, count: Int)] = []

        for (videoId, refs) in grouped {
            if let video = libraryViewModel.videos.first(where: { $0.id == videoId }) {
                results.append((video: video, count: refs.count))
            }
        }

        return results.sorted { $0.count > $1.count }.prefix(6).map { $0 }
    }

    var usedThreePlusTimes: Int {
        let grouped = Dictionary(grouping: allReferences, by: \.inspirationVideoId)
        return grouped.values.filter { $0.count >= 3 }.count
    }

    private var tagBreakdown: [(tag: String, count: Int, percentage: Int)] {
        let filtered = allReferences.filter { !$0.referenceTag.isEmpty }
        guard !filtered.isEmpty else { return [] }

        let grouped = Dictionary(grouping: filtered, by: \.referenceTag)
        let total = filtered.count

        return grouped.map { tag, refs in
            let pct = Int((Double(refs.count) / Double(total) * 100).rounded())
            return (tag: tag, count: refs.count, percentage: pct)
        }
        .sorted { $0.count > $1.count }
    }

    private var dominantTag: String? {
        tagBreakdown.first?.tag
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: RS.md) {
            Text("No references yet")
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)

            Text("Add videos from your Library to a Story to see your influences here.")
                .font(RF.bodySm)
                .foregroundStyle(Color.riffitTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RS.md)
        }
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        HStack(spacing: RS.sm) {
            summaryPill(value: "\(totalReferenceCount)", label: "References")
            summaryPill(value: "\(uniqueVideoCount)", label: "Unique videos")
            summaryPill(value: "\(usedThreePlusTimes)", label: "Used 3+×")
        }
    }

    private func summaryPill(value: String, label: String) -> some View {
        VStack(spacing: RS.xs) {
            Text(value)
                .font(.custom("DMSans-Medium", size: 20))
                .foregroundStyle(Color.riffitTextPrimary)

            Text(label)
                .font(RF.meta)
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RS.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
    }

    // MARK: - Section Builder

    private func influencesSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            Text(title)
                .font(RF.tag)
                .textCase(.uppercase)
                .tracking(0.06 * 11)
                .foregroundStyle(Color.riffitTextTertiary)

            content()
        }
    }

    // MARK: - Video Row

    private func videoRow(rank: Int, video: InspirationVideo, count: Int) -> some View {
        HStack(spacing: RS.sm) {
            // Rank number
            Text("\(rank)")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextTertiary)
                .frame(width: 18)

            // Platform dot
            Circle()
                .fill(platformColor(video.platform))
                .frame(width: 7, height: 7)

            // Video info
            VStack(alignment: .leading, spacing: 2) {
                Text(videoTitle(video))
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundStyle(Color.riffitTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("\(video.platform.displayLabel)")
                    .font(RF.meta)
                    .foregroundStyle(Color.riffitTextTertiary)
            }

            Spacer()

            // Count badge
            Text("\(count)×")
                .font(.custom("DMSans-Medium", size: 10))
                .foregroundStyle(countBadgeForeground(count))
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(countBadgeBackground(count))
                .clipShape(Capsule())
        }
        .padding(RS.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
    }

    private func videoTitle(_ video: InspirationVideo) -> String {
        if let title = video.title, !title.isEmpty {
            return title
        }
        // Truncated URL fallback
        guard let url = URL(string: video.url), let host = url.host else {
            return video.url
        }
        let path = url.path
        let display = host + (path.count > 1 ? path : "")
        return display.count > 40 ? String(display.prefix(40)) + "..." : display
    }

    private func platformColor(_ platform: InspirationVideo.Platform) -> Color {
        switch platform {
        case .youtube:   return Color(red: 232/255, green: 69/255, blue: 60/255)
        case .tiktok:    return Color(red: 105/255, green: 201/255, blue: 208/255)
        case .instagram: return Color(red: 193/255, green: 53/255, blue: 132/255)
        case .linkedin:  return Color(red: 0/255, green: 119/255, blue: 181/255)
        case .x:         return Color.riffitTextTertiary
        }
    }

    private func countBadgeForeground(_ count: Int) -> Color {
        count >= 3 ? Color.riffitPrimary : Color.riffitTextTertiary
    }

    private func countBadgeBackground(_ count: Int) -> Color {
        count >= 3 ? Color.riffitPrimaryTint : Color.riffitElevated
    }

    // MARK: - Tag Row

    private func tagRow(tag: String, count: Int, percentage: Int) -> some View {
        VStack(spacing: RS.sm) {
            HStack {
                Text(tag)
                    .font(.custom("DMSans-Medium", size: 13))
                    .foregroundStyle(Color.riffitTextPrimary)

                Spacer()

                Text("\(percentage)%")
                    .font(RF.bodySm)
                    .foregroundStyle(Color.riffitTextSecondary)
            }

            // Animated progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.riffitElevated)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(tagBarColor(tag))
                        .frame(
                            width: animateProgress
                                ? geo.size.width * CGFloat(percentage) / 100
                                : 0,
                            height: 4
                        )
                }
            }
            .frame(height: 4)
        }
        .padding(RS.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
    }

    private func tagBarColor(_ tag: String) -> Color {
        switch tag {
        case "Hook":        return Color.riffitPrimary
        case "Format":      return Color(red: 216/255, green: 90/255, blue: 48/255)
        case "B-Roll":      return Color(red: 55/255, green: 138/255, blue: 221/255)
        case "Editing":     return Color(red: 29/255, green: 158/255, blue: 117/255)
        case "Topic":       return Color(red: 127/255, green: 119/255, blue: 221/255)
        case "Inspiration": return Color.riffitTextTertiary
        default:            return Color.riffitPrimary
        }
    }

    // MARK: - Pattern Card

    private func patternCard(dominantTag: String) -> some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            Text("PATTERN SPOTTED")
                .font(.custom("DMSans-Medium", size: 10))
                .textCase(.uppercase)
                .tracking(0.06 * 10)
                .foregroundStyle(Color.riffitTeal400)

            insightText(for: dominantTag)
                .font(RF.bodySm)
                .foregroundStyle(Color.riffitTextSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RS.smPlus)
        .background(Color.riffitTealTint)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(Color.riffitTeal400, lineWidth: 0.5)
        )
    }

    private func insightText(for tag: String) -> Text {
        let bold = Text(tag).fontWeight(.semibold).foregroundColor(Color.riffitTextPrimary)

        switch tag {
        case "Hook":
            return Text("You lean on ") + bold + Text(" references heavily. Your editing references are thin — blind spot or confidence?")
        case "Editing":
            return bold + Text(" is your biggest influence. You have a strong eye for craft.")
        case "Format":
            return bold + Text(" is where you draw the most inspiration. You think in structure.")
        case "B-Roll":
            return bold + Text(" dominates your references. Visual storytelling is your lens.")
        case "Topic":
            return bold + Text(" references lead your saves. You're idea-driven first.")
        default:
            return Text("You have a clear creative focus. Keep building on it.")
        }
    }
}
