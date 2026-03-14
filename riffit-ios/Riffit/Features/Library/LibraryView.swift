import SwiftUI

/// The main screen — folders at the top, unfiled ideas below.
/// Drag an idea onto a folder to organize it.
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showAddSheet: Bool = false
    @State private var showNewFolderAlert: Bool = false
    @State private var newFolderName: String = ""

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.isEmpty {
                ProgressView()
                    .tint(Color.riffitPrimary)
            } else if viewModel.isEmpty {
                emptyState
            } else {
                mainContent
            }
        }
        .navigationTitle("Ideas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("New Idea", systemImage: "lightbulb")
                    }

                    Button {
                        newFolderName = ""
                        showNewFolderAlert = true
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddInspirationView(viewModel: viewModel)
        }
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    viewModel.createFolder(name: trimmed)
                }
            }
        }
        .task {
            await viewModel.fetchVideos()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: .smPlus) {
                // Folders section
                if !viewModel.folders.isEmpty {
                    foldersSection
                }

                // Unfiled ideas
                let unfiled = viewModel.unfiledVideos
                if !unfiled.isEmpty {
                    if !viewModel.folders.isEmpty {
                        sectionHeader("Unfiled")
                    }

                    ForEach(unfiled) { video in
                        NavigationLink(value: video) {
                            IdeaRow(video: video, tags: viewModel.tags(for: video.id))
                        }
                        .buttonStyle(.plain)
                        .draggable(video.id.uuidString)
                    }
                }
            }
            .padding(.horizontal, .md)
            .padding(.vertical, .smPlus)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .navigationDestination(for: InspirationVideo.self) { video in
            InspirationDetailView(video: video, viewModel: viewModel)
        }
        .navigationDestination(for: IdeaFolder.self) { folder in
            FolderDetailView(folder: folder, viewModel: viewModel)
        }
    }

    // MARK: - Folders Section

    private var foldersSection: some View {
        ForEach(viewModel.folders) { folder in
            FolderDropTarget(folder: folder, viewModel: viewModel)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .riffitLabel()
            .foregroundStyle(Color.riffitTextTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, .sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: .md) {
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundStyle(Color.riffitPrimary)

            Text("No ideas yet")
                .riffitTitle()
                .foregroundStyle(Color.riffitTextPrimary)

            Text("Found an Instagram reel that sparks something?\nDrop the link here with a quick note.")
                .riffitBody()
                .foregroundStyle(Color.riffitTextSecondary)
                .multilineTextAlignment(.center)

            RiffitButton(title: "Add Your First Idea", variant: .primary) {
                showAddSheet = true
            }
            .padding(.top, .sm)
        }
        .padding(.horizontal, .xl)
    }
}

// MARK: - Folder Row

struct FolderRow: View {
    let folder: IdeaFolder
    let count: Int

    var body: some View {
        HStack(spacing: .smPlus) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(Color.riffitPrimary)

            Text(folder.name)
                .riffitHeading()
                .foregroundStyle(Color.riffitTextPrimary)

            Spacer()

            Text("\(count)")
                .riffitCaption()
                .foregroundStyle(Color.riffitTextTertiary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .padding(.md)
        .background(Color.riffitSurface)
        .cornerRadius(.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: .cardRadius)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - Folder Drop Target

/// Wraps a FolderRow with drop-target behavior and a highlight when
/// an idea is dragged over it. Folders themselves are never draggable.
struct FolderDropTarget: View {
    let folder: IdeaFolder
    @ObservedObject var viewModel: LibraryViewModel
    @State private var isTargeted: Bool = false

    var body: some View {
        NavigationLink(value: folder) {
            FolderRow(
                folder: folder,
                count: viewModel.videos(in: folder).count
            )
            // Highlight border when a drag hovers over this folder
            .overlay(
                RoundedRectangle(cornerRadius: .cardRadius)
                    .stroke(Color.riffitPrimary, lineWidth: isTargeted ? 2 : 0)
            )
            .scaleEffect(isTargeted ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isTargeted)
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            guard let idString = items.first,
                  let videoId = UUID(uuidString: idString),
                  // Only accept video IDs, not folder IDs
                  viewModel.videos.contains(where: { $0.id == videoId })
            else { return false }
            viewModel.moveVideo(videoId, to: folder.id)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}

// MARK: - Idea Row

/// Note is the headline, tags show below it, URL is the footer.
struct IdeaRow: View {
    let video: InspirationVideo
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: .sm) {
            // Note — the primary identifier
            if let note = video.userNote, !note.isEmpty {
                Text(note)
                    .riffitHeading()
                    .foregroundStyle(Color.riffitTextPrimary)
                    .lineLimit(2)
            } else {
                Text("No note")
                    .riffitHeading()
                    .foregroundStyle(Color.riffitTextTertiary)
                    .italic()
            }

            // Tags row
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.riffitPrimary)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                            .background(Color.riffitPrimaryTint)
                            .clipShape(Capsule())
                    }
                }
            }

            // IG link
            HStack(spacing: 6) {
                Image(systemName: "camera")
                    .font(.caption2)
                    .foregroundStyle(Color.riffitTeal400)

                Text(shortURL)
                    .riffitCaption()
                    .foregroundStyle(Color.riffitTextTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.md)
        .background(Color.riffitSurface)
        .cornerRadius(.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: .cardRadius)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    private var shortURL: String {
        guard let url = URL(string: video.url) else { return video.url }
        let path = url.path
        if path.count > 1 {
            return String(path.dropFirst())
        }
        return url.host ?? video.url
    }
}

// MARK: - InspirationVideo Hashable (for NavigationLink)

extension InspirationVideo: Hashable {
    static func == (lhs: InspirationVideo, rhs: InspirationVideo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
