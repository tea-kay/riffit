import SwiftUI

/// Modal for adding a reference from the Library to a Story.
/// Step 1: Pick an idea from the user's saved InspirationVideos.
/// Step 2: Pick which tag you're referencing it for.
struct AddReferenceView: View {
    let story: Story
    @ObservedObject var viewModel: StorybankViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedVideo: InspirationVideo?
    @State private var selectedSectionId: UUID?
    @State private var step: Step = .pickVideo
    @State private var searchText: String = ""
    @State private var selectedFolder: IdeaFolder?

    enum Step {
        case pickVideo
        case pickSection
    }

    /// The story's asset sections — used as the reference destination options.
    private var storySections: [AssetSection] {
        viewModel.sections(for: story.id)
    }

    /// Videos scoped to the current folder (or all active if no folder selected).
    private var scopedVideos: [InspirationVideo] {
        if let folder = selectedFolder {
            return libraryViewModel.videos(in: folder).filter { $0.status != .archived }
        }
        return libraryViewModel.activeVideos
    }

    /// Filtered videos based on search query within the current scope.
    private var filteredVideos: [InspirationVideo] {
        guard !searchText.isEmpty else { return scopedVideos }

        let query = searchText.lowercased()
        return scopedVideos.filter { video in
            if let title = video.title, title.lowercased().contains(query) {
                return true
            }
            if let note = video.userNote, note.lowercased().contains(query) {
                return true
            }
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
                case .pickSection:
                    pickSectionStep
                }
            }
            .navigationTitle(step == .pickVideo ? "Pick an Idea" : "Add to section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.riffitTextSecondary)
                }

                if step == .pickSection {
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

            // Breadcrumb when inside a folder — tap to go back
            if let folder = selectedFolder {
                Button {
                    withAnimation { selectedFolder = nil }
                } label: {
                    HStack(spacing: RS.xs) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                        Text("All Ideas")
                            .font(RF.caption)
                        Text("/")
                            .font(RF.caption)
                            .foregroundStyle(Color.riffitTextTertiary)
                        Text(folder.name)
                            .font(RF.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.riffitTeal400)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, RS.md)
                .padding(.bottom, RS.sm)
            }

            if filteredVideos.isEmpty && (selectedFolder != nil || !libraryViewModel.folders.isEmpty == false) {
                Spacer()
                emptyPickerState
                Spacer()
            } else if filteredVideos.isEmpty && selectedFolder == nil && libraryViewModel.folders.isEmpty {
                Spacer()
                emptyPickerState
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: RS.smPlus) {
                        // Show folders at top level when not searching and no folder selected
                        if selectedFolder == nil && searchText.isEmpty && !libraryViewModel.folders.isEmpty {
                            ForEach(libraryViewModel.folders) { folder in
                                PickerFolderRow(
                                    folder: folder,
                                    count: libraryViewModel.videos(in: folder).filter { $0.status != .archived }.count
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation { selectedFolder = folder }
                                }
                            }
                        }

                        // Videos (unfiled at top level, or all in selected folder)
                        let videosToShow: [InspirationVideo] = {
                            // At top level with no search, show only unfiled videos
                            // (filed ones are accessible through their folders)
                            if selectedFolder == nil && searchText.isEmpty && !libraryViewModel.folders.isEmpty {
                                return filteredVideos.filter { libraryViewModel.videoFolderMap[$0.id] == nil }
                            }
                            return filteredVideos
                        }()

                        if !videosToShow.isEmpty {
                            // "Unfiled" label when folders exist and we're at top level
                            if selectedFolder == nil && searchText.isEmpty && !libraryViewModel.folders.isEmpty {
                                Text("Unfiled")
                                    .font(RF.tag)
                                    .textCase(.uppercase)
                                    .tracking(0.08 * 12)
                                    .foregroundStyle(Color.riffitTextTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            ForEach(videosToShow) { video in
                                PickerCard(
                                    video: video,
                                    tags: libraryViewModel.tags(for: video.id)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedVideo = video
                                    if storySections.isEmpty {
                                        // No sections in this story — add reference directly
                                        viewModel.addReference(to: story.id, videoId: video.id, tag: "")
                                        dismiss()
                                    } else {
                                        withAnimation { step = .pickSection }
                                    }
                                }
                            }
                        }

                        // Show empty state if nothing to display
                        if videosToShow.isEmpty && (selectedFolder != nil || libraryViewModel.folders.isEmpty) {
                            emptyPickerState
                                .padding(.top, RS.xl3)
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

    // MARK: - Step 2: Pick Section

    private var pickSectionStep: some View {
        VStack(spacing: RS.lg) {
            Text("Which section is this reference for?")
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RS.lg)
                .padding(.top, RS.lg)

            // Section options — the story's asset sections
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: RS.smPlus) {
                // "None" option for unsectioned references
                Button {
                    selectedSectionId = nil
                    addSelectedReference(sectionName: "")
                } label: {
                    Text("No section")
                        .font(RF.button)
                        .foregroundStyle(Color.riffitTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RS.smPlus)
                        .background(Color.riffitSurface)
                        .cornerRadius(RR.button)
                        .overlay(
                            RoundedRectangle(cornerRadius: RR.button)
                                .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                ForEach(storySections) { section in
                    Button {
                        selectedSectionId = section.id
                        addSelectedReference(sectionName: section.name)
                    } label: {
                        HStack(spacing: RS.xs) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.riffitTeal400)
                                .frame(width: 3, height: 16)

                            Text(section.name)
                                .font(RF.button)
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.riffitTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RS.smPlus)
                        .background(Color.riffitSurface)
                        .cornerRadius(RR.button)
                        .overlay(
                            RoundedRectangle(cornerRadius: RR.button)
                                .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, RS.md)

            Spacer()
        }
    }

    /// Adds the selected video as a reference and dismisses.
    private func addSelectedReference(sectionName: String) {
        guard let video = selectedVideo else { return }
        viewModel.addReference(to: story.id, videoId: video.id, tag: sectionName)
        dismiss()
    }
}

// MARK: - Picker Card

/// Simplified card for the reference picker showing title, tags, and URL.
struct PickerCard: View {
    let video: InspirationVideo
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            // Title or note as headline
            if let title = video.title, !title.isEmpty {
                Text(title)
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

// MARK: - Picker Folder Row

/// Folder row in the reference picker — matches the Library folder style.
struct PickerFolderRow: View {
    let folder: IdeaFolder
    let count: Int

    var body: some View {
        HStack(spacing: RS.smPlus) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(Color.riffitPrimary)

            Text(folder.name)
                .font(RF.label)
                .foregroundStyle(Color.riffitTextPrimary)

            Spacer()

            Text("\(count)")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextTertiary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .padding(RS.md)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }
}
