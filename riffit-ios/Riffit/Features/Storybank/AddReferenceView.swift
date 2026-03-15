import SwiftUI

/// Modal for adding a reference from the Library to a Story.
/// Step 1: Pick an idea from the user's saved InspirationVideos.
/// Step 2: Pick which tag you're referencing it for.
/// The AI relevance note will be generated asynchronously via an Edge Function.
struct AddReferenceView: View {
    let story: Story
    @ObservedObject var viewModel: StorybankViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedVideo: InspirationVideo?
    @State private var selectedTag: String?
    @State private var step: Step = .pickVideo
    @State private var searchText: String = ""

    enum Step {
        case pickVideo
        case pickTag
    }

    /// The reference tags a creator can pick from.
    private let referenceTags: [String] = [
        "Hook", "Editing", "B-Roll", "Format", "Topic", "Inspiration"
    ]

    /// Filtered videos based on search query.
    private var filteredVideos: [InspirationVideo] {
        let active = libraryViewModel.activeVideos
        guard !searchText.isEmpty else { return active }

        let query = searchText.lowercased()
        return active.filter { video in
            // Search by note text
            if let note = video.userNote, note.lowercased().contains(query) {
                return true
            }
            // Search by summary
            if let summary = video.summary, summary.lowercased().contains(query) {
                return true
            }
            // Search by tags
            let tags = libraryViewModel.tags(for: video.id)
            if tags.contains(where: { $0.lowercased().contains(query) }) {
                return true
            }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.riffitBackground
                    .ignoresSafeArea()

                switch step {
                case .pickVideo:
                    pickVideoStep
                case .pickTag:
                    pickTagStep
                }
            }
            .navigationTitle(step == .pickVideo ? "Pick an Idea" : "What are you referencing?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.riffitTextSecondary)
                }

                if step == .pickTag {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation { step = .pickVideo }
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(Color.riffitTextSecondary)
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(RR.modal)
        .task {
            await libraryViewModel.fetchVideos()
        }
    }

    // MARK: - Step 1: Pick Video

    private var pickVideoStep: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: RS.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.callout)
                    .foregroundStyle(Color.riffitTextTertiary)

                TextField("Search ideas...", text: $searchText)
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextPrimary)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(Color.riffitTextTertiary)
                    }
                }
            }
            .padding(RS.smPlus)
            .background(Color.riffitSurface)
            .cornerRadius(RR.input)
            .padding(.horizontal, RS.md)
            .padding(.vertical, RS.sm)

            if filteredVideos.isEmpty {
                Spacer()
                emptyPickerState
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: RS.smPlus) {
                        ForEach(filteredVideos) { video in
                            PickerCard(
                                video: video,
                                tags: libraryViewModel.tags(for: video.id)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedVideo = video
                                withAnimation { step = .pickTag }
                            }
                        }
                    }
                    .padding(.horizontal, RS.md)
                    .padding(.vertical, RS.sm)
                }
            }
        }
    }

    // MARK: - Empty Picker State

    private var emptyPickerState: some View {
        VStack(spacing: RS.sm) {
            Image(systemName: "lightbulb")
                .font(.system(size: 36))
                .foregroundStyle(Color.riffitTextTertiary)

            if searchText.isEmpty {
                Text("No ideas saved yet")
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextSecondary)

                Text("Go to Ideas to save your first reel.")
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextTertiary)
            } else {
                Text("No matching ideas")
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, RS.xl)
    }

    // MARK: - Step 2: Pick Tag

    private var pickTagStep: some View {
        VStack(spacing: RS.lg) {
            Text("What aspect of this video are you referencing?")
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RS.lg)
                .padding(.top, RS.lg)

            // Tag grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RS.smPlus) {
                ForEach(referenceTags, id: \.self) { tag in
                    Button {
                        selectedTag = tag
                    } label: {
                        Text(tag)
                            .font(RF.button)
                            .foregroundStyle(
                                selectedTag == tag
                                    ? Color.riffitOnPrimary
                                    : Color.riffitTextPrimary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, RS.smPlus)
                            .background(
                                selectedTag == tag
                                    ? Color.riffitPrimary
                                    : Color.riffitSurface
                            )
                            .cornerRadius(RR.button)
                            .overlay(
                                RoundedRectangle(cornerRadius: RR.button)
                                    .stroke(
                                        selectedTag == tag
                                            ? Color.clear
                                            : Color.riffitBorderDefault,
                                        lineWidth: 0.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, RS.md)

            Spacer()

            // Add reference button
            RiffitButton(title: "Add Reference", variant: .primary) {
                if let video = selectedVideo, let tag = selectedTag {
                    viewModel.addReference(to: story.id, videoId: video.id, tag: tag)
                    dismiss()
                }
            }
            .padding(.horizontal, RS.md)
            .padding(.bottom, RS.lg)
            .opacity(selectedTag != nil ? 1.0 : 0.4)
            .disabled(selectedTag == nil)
        }
    }
}

// MARK: - Picker Card

/// Simplified card for the reference picker showing note, tags, URL, and alignment.
struct PickerCard: View {
    let video: InspirationVideo
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            // Summary or note as headline
            if let summary = video.summary, !summary.isEmpty {
                Text(summary)
                    .font(RF.label)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .lineLimit(2)
            } else if let note = video.userNote, !note.isEmpty {
                Text(note)
                    .font(RF.label)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .lineLimit(2)
            }

            // Tags
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(RF.tag)
                            .foregroundStyle(Color.riffitPrimary)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(Color.riffitPrimaryTint)
                            .clipShape(Capsule())
                    }
                }
            }

            // Platform + URL footer
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.riffitTeal400)
                    .frame(width: 5, height: 5)

                Text(video.platform.displayLabel)
                    .font(RF.meta)
                    .foregroundStyle(Color.riffitTextTertiary)

                Text(shortURL)
                    .font(RF.meta)
                    .foregroundStyle(Color.riffitTextTertiary)
                    .lineLimit(1)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RS.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    private var shortURL: String {
        guard let url = URL(string: video.url) else { return video.url }
        let path = url.path
        if path.count > 30 {
            return String(path.prefix(30)) + "..."
        }
        return path.count > 1 ? String(path.dropFirst()) : (url.host ?? video.url)
    }
}
