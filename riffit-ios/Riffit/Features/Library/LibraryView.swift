import SwiftUI

/// The main screen — folders at the top, unfiled ideas below.
/// Drag an idea onto a folder to organize it.
struct LibraryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: LibraryViewModel
    @EnvironmentObject var storybankViewModel: StorybankViewModel
    @State private var showAddSheet: Bool = false
    @State private var showNewFolderAlert: Bool = false
    @State private var showActionSheet: Bool = false
    @State private var newFolderName: String = ""
    @State private var videoToDelete: InspirationVideo?
    @State private var showDeleteConfirm: Bool = false
    @State private var searchText: String = ""
    @State private var selectedTagFilter: String?

    private let filterTags: [String] = ["Hook", "Editing", "B-Roll", "Format", "Topic", "Inspiration"]

    /// First initial of the user's name or email for avatar fallback
    private var userAvatarInitial: String {
        if let name = appState.currentUser?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty, let first = name.first {
            return String(first).uppercased()
        }
        if let first = appState.currentUser?.email.first {
            return String(first).uppercased()
        }
        return "?"
    }

    /// Videos filtered by search query and tag, respecting folder scope.
    private var searchFilteredVideos: [InspirationVideo] {
        var results = viewModel.videos.filter { $0.status != .archived }

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter { video in
                if let title = video.title, title.lowercased().contains(query) { return true }
                if let note = video.userNote, note.lowercased().contains(query) { return true }
                if viewModel.tags(for: video.id).contains(where: { $0.lowercased().contains(query) }) { return true }
                return false
            }
        }

        // Tag filter
        if let tag = selectedTagFilter {
            results = results.filter { viewModel.tags(for: $0.id).contains(tag) }
        }

        return results
    }

    /// Whether search or tag filter is active — hides folder grouping
    private var isFiltering: Bool {
        !searchText.isEmpty || selectedTagFilter != nil
    }

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Ideas")
                    .font(RF.title)
                    .foregroundStyle(Color.riffitTextPrimary)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showActionSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddInspirationView(viewModel: viewModel)
        }
        .riffitModal(isPresented: $showActionSheet) {
            RiffitActionModal(
                actions: [
                    .init(label: "New Idea", icon: "lightbulb") {
                        showAddSheet = true
                    },
                    .init(label: "New Folder", icon: "folder.badge.plus") {
                        newFolderName = ""
                        showNewFolderAlert = true
                    },
                ],
                onDismiss: {
                    showActionSheet = false
                }
            )
        }
        .riffitModal(isPresented: $showNewFolderAlert) {
            RiffitInputModal(
                title: "New Folder",
                placeholder: "Folder name",
                actionLabel: "Create",
                text: $newFolderName,
                onCancel: {
                    showNewFolderAlert = false
                },
                onAction: { name in
                    viewModel.createFolder(name: name)
                    showNewFolderAlert = false
                }
            )
        }
        .task {
            await viewModel.fetchVideos()
        }
        .alert("Delete this idea?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let video = videoToDelete {
                    storybankViewModel.removeReferences(for: video.id)
                    viewModel.deleteVideo(video.id)
                    videoToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                videoToDelete = nil
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: RS.smPlus) {
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

                // Tag filter bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: RS.sm) {
                        Button {
                            selectedTagFilter = nil
                        } label: {
                            Text("All")
                                .font(RF.tag)
                                .foregroundStyle(selectedTagFilter == nil ? Color.riffitPrimary : Color.riffitTextSecondary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, RS.smPlus)
                                .background(selectedTagFilter == nil ? Color.riffitPrimaryTint : Color.riffitElevated)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedTagFilter == nil ? Color.riffitPrimary : Color.riffitBorderDefault, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)

                        ForEach(filterTags, id: \.self) { tag in
                            Button {
                                selectedTagFilter = tag
                            } label: {
                                Text(tag)
                                    .font(RF.tag)
                                    .foregroundStyle(selectedTagFilter == tag ? Color.riffitPrimary : Color.riffitTextSecondary)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, RS.smPlus)
                                    .background(selectedTagFilter == tag ? Color.riffitPrimaryTint : Color.riffitElevated)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(selectedTagFilter == tag ? Color.riffitPrimary : Color.riffitBorderDefault, lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Content — flat filtered list when filtering, folder-grouped when not
                if isFiltering {
                    // Flat filtered results
                    if searchFilteredVideos.isEmpty {
                        VStack(spacing: RS.sm) {
                            Text("No matching ideas")
                                .font(RF.bodyMd)
                                .foregroundStyle(Color.riffitTextTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RS.xl)
                    } else {
                        ForEach(searchFilteredVideos) { video in
                            NavigationLink(value: video) {
                                IdeaRow(video: video, tags: viewModel.tags(for: video.id), avatarUrl: appState.currentUser?.avatarUrl, avatarInitial: userAvatarInitial)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    videoToDelete = video
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } else {
                    // Normal folder-grouped view
                    if !viewModel.folders.isEmpty {
                        foldersSection
                    }

                    let unfiled = viewModel.unfiledVideos
                    if !unfiled.isEmpty {
                        if !viewModel.folders.isEmpty {
                            sectionHeader("Unfiled")
                        }

                        ForEach(unfiled) { video in
                            NavigationLink(value: video) {
                                IdeaRow(video: video, tags: viewModel.tags(for: video.id), avatarUrl: appState.currentUser?.avatarUrl, avatarInitial: userAvatarInitial)
                            }
                            .buttonStyle(.plain)
                            .draggable(video.id.uuidString)
                            .contextMenu {
                                Button(role: .destructive) {
                                    videoToDelete = video
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, RS.md)
            .padding(.vertical, RS.smPlus)
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
            .font(RF.tag)
            .textCase(.uppercase)
            .tracking(0.08 * 12)
            .foregroundStyle(Color.riffitTextTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, RS.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ZStack {
            gridBackground

            VStack(spacing: 0) {
                Spacer()

                // Illustration — fixed 140pt frame so both tabs align
                WaveBarrelIllustration()
                    .frame(width: 180, height: 140)

                Spacer().frame(height: RS.lg)  // 24pt

                Text("Nothing here yet")
                    .font(RF.heading)
                    .foregroundStyle(Color.riffitTextPrimary)

                Spacer().frame(height: RS.sm)  // 8pt

                Text("Catch your first idea.")
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextSecondary)

                Spacer().frame(height: RS.lg)  // 24pt

                RiffitButton(title: "Drop your first find", variant: .ghostGold) {
                    showAddSheet = true
                }
                .padding(.horizontal, RS.xl2)

                Spacer()
            }
        }
    }

    /// Beige grid background for empty states.
    /// Does NOT ignore safe area — nav bar keeps its own background.
    private var gridBackground: some View {
        Canvas { context, size in
            // Fill with grid background color
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.riffitGridBackground)
            )

            // Vertical grid lines — 73pt spacing
            let verticalSpacing: CGFloat = 73
            var x: CGFloat = verticalSpacing
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Color.riffitGridLine), lineWidth: 0.4)
                x += verticalSpacing
            }

            // Horizontal grid lines — 85pt spacing
            let horizontalSpacing: CGFloat = 85
            var y: CGFloat = horizontalSpacing
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Color.riffitGridLine), lineWidth: 0.4)
                y += horizontalSpacing
            }
        }
    }
}

// MARK: - Folder Row

struct FolderRow: View {
    let folder: IdeaFolder
    let count: Int

    var body: some View {
        HStack(spacing: RS.smPlus) {
            Image(systemName: "folder.fill")
                .font(.title3)
                .foregroundStyle(Color.riffitPrimary)

            Text(folder.name)
                .font(RF.heading)
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
        .cornerRadius(RR.card)
        .overlay(
            RoundedRectangle(cornerRadius: RR.card)
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
                RoundedRectangle(cornerRadius: RR.card)
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

/// Delegates to InspirationCard for consistent card layout across the app.
struct IdeaRow: View {
    let video: InspirationVideo
    let tags: [String]
    var avatarUrl: String? = nil
    var avatarInitial: String = "?"

    var body: some View {
        InspirationCard(video: video, tags: tags, avatarUrl: avatarUrl, avatarInitial: avatarInitial)
    }
}

// MARK: - Wave Barrel Illustration

/// Concentric teal rings with a sunset core — the wave barrel.
/// Ring order adapts to color scheme:
///   Light: #1A8A96 -> #0F6B75 -> #0A4A52 -> gold -> amber -> coral
///   Dark:  #0A4A52 -> #0F6B75 -> #1A8A96 -> gold -> amber -> coral
struct WaveBarrelIllustration: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2

            // Teal ring order flips between light and dark mode
            let tealColors: [Color] = colorScheme == .dark
                ? [.riffitTeal900, .riffitTeal600, .riffitTeal400]  // dark outer -> light inner
                : [.riffitTeal400, .riffitTeal600, .riffitTeal900]  // light outer -> dark inner

            let tealRadii: [CGFloat] = [1.0, 0.82, 0.64]

            for (i, color) in tealColors.enumerated() {
                let r = maxRadius * tealRadii[i]
                let rect = CGRect(
                    x: center.x - r, y: center.y - r,
                    width: r * 2, height: r * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }

            // Sunset core (same in both modes: gold -> amber -> coral)
            let sunsetRings: [(color: Color, radiusFraction: CGFloat)] = [
                (.riffitPrimary, 0.46),
                (.riffitPrimaryPressed, 0.30),
                (Color.riffitDanger, 0.16),
            ]

            for ring in sunsetRings {
                let r = maxRadius * ring.radiusFraction
                let rect = CGRect(
                    x: center.x - r, y: center.y - r,
                    width: r * 2, height: r * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(ring.color))
            }

            // White foam arc at the top of the barrel
            let foamRadius = maxRadius * 0.95
            var foamPath = Path()
            foamPath.addArc(
                center: center,
                radius: foamRadius,
                startAngle: .degrees(-160),
                endAngle: .degrees(-20),
                clockwise: false
            )
            context.stroke(foamPath, with: .color(.white.opacity(0.7)), lineWidth: 2.5)

            // Two water lines below the barrel
            let lineY1 = center.y + maxRadius + 12
            let lineY2 = center.y + maxRadius + 22

            for lineY in [lineY1, lineY2] {
                var linePath = Path()
                linePath.move(to: CGPoint(x: center.x - 30, y: lineY))
                linePath.addQuadCurve(
                    to: CGPoint(x: center.x + 30, y: lineY),
                    control: CGPoint(x: center.x, y: lineY - 5)
                )
                context.stroke(linePath, with: .color(Color.riffitTeal600.opacity(0.5)), lineWidth: 1.5)
            }
        }
    }
}

// MARK: - InspirationVideo Hashable (for NavigationLink)

/// Equatable compares id + mutable fields so SwiftUI re-renders
/// cards when title or other editable properties change.
/// Hash still uses id only — identity doesn't change on edit.
extension InspirationVideo: Hashable {
    static func == (lhs: InspirationVideo, rhs: InspirationVideo) -> Bool {
        lhs.id == rhs.id
        && lhs.title == rhs.title
        && lhs.status == rhs.status
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
