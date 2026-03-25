import SwiftUI

/// The Storybank tab — the creator's workspace for organizing stories.
/// Each story collects assets (voice notes, video, images, text) and
/// references to inspiration videos from the Library.
struct StorybankView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: StorybankViewModel
    @State private var showNewStoryAlert: Bool = false
    @State private var newStoryTitle: String = ""
    @State private var showNewFolderAlert: Bool = false
    @State private var newFolderName: String = ""
    @State private var showActionSheet: Bool = false
    @Environment(\.colorScheme) private var colorScheme

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
                storyList
            }
        }
        .navigationTitle("Storybank")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Storybank")
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
        .riffitModal(isPresented: $showActionSheet) {
            RiffitActionModal(
                actions: [
                    .init(label: "New Story", icon: "doc.text") {
                        newStoryTitle = ""
                        showNewStoryAlert = true
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
        .riffitModal(isPresented: $showNewStoryAlert) {
            RiffitInputModal(
                title: "New Story",
                placeholder: "Story title",
                actionLabel: "Create",
                text: $newStoryTitle,
                onCancel: {
                    showNewStoryAlert = false
                },
                onAction: { title in
                    viewModel.createStory(title: title)
                    showNewStoryAlert = false
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
            await viewModel.fetchStories()
        }
    }

    // MARK: - Story List

    private var storyList: some View {
        ScrollView {
            LazyVStack(spacing: RS.smPlus) {
                // Folders section
                if !viewModel.folders.isEmpty {
                    ForEach(viewModel.folders) { folder in
                        StoryFolderDropTarget(folder: folder, viewModel: viewModel)
                    }
                }

                // Unfiled stories
                let unfiled = viewModel.unfiledStories
                if !unfiled.isEmpty {
                    if !viewModel.folders.isEmpty {
                        Text("Unfiled")
                            .font(RF.tag)
                            .textCase(.uppercase)
                            .tracking(0.08 * 12)
                            .foregroundStyle(Color.riffitTextTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, RS.sm)
                    }

                    ForEach(unfiled) { story in
                        NavigationLink(value: story) {
                            StoryCard(story: story, countsLabel: viewModel.countsLabel(for: story.id), avatarUrl: appState.currentUser?.avatarUrl, avatarInitial: userAvatarInitial)
                        }
                        .buttonStyle(.plain)
                        .draggable(story.id.uuidString)
                    }
                }
            }
            .padding(.horizontal, RS.md)
            .padding(.vertical, RS.smPlus)
        }
        .refreshable {
            await viewModel.fetchStories()
        }
        .navigationDestination(for: Story.self) { story in
            StoryDetailView(story: story, viewModel: viewModel)
        }
        .navigationDestination(for: StoryFolder.self) { folder in
            StoryFolderDetailView(folder: folder, viewModel: viewModel)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ZStack {
            // Grid background — matches Library empty state exactly
            storybankGridBackground

            VStack(spacing: RS.md) {
                Spacer()

                GemIllustration()
                    .frame(width: 100, height: 108)

                Text(colorScheme == .dark
                     ? "Every story needs a spark."
                     : "Your story starts here.")
                    .font(RF.heading)
                    .foregroundStyle(Color.riffitTextPrimary)

                Text("Start building your first story.")
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextSecondary)

                RiffitButton(title: "Start a new story", variant: .primary) {
                    newStoryTitle = ""
                    showNewStoryAlert = true
                }
                .padding(.horizontal, RS.xl2)
                .padding(.top, RS.sm)

                Spacer()
            }
        }
    }

    /// Grid background matching the Library empty state.
    /// Beige base with grid lines in light mode, #111111 with dimmed grid in dark mode.
    private var storybankGridBackground: some View {
        Canvas { context, size in
            // Fill with grid background color (adapts to color scheme via token)
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

// MARK: - Gem Illustration

/// Geometric faceted gem built from 8 triangular polygons using Path.
/// Used as the Storybank empty state illustration in both light and dark modes.
struct GemIllustration: View {
    var body: some View {
        Canvas { context, size in
            // Scale paths to fit the provided frame
            let scaleX = size.width / 100
            let scaleY = size.height / 108

            // Helper to draw a filled triangle from three points
            func drawFacet(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, color: Color) {
                var path = Path()
                path.move(to: CGPoint(x: p1.x * scaleX, y: p1.y * scaleY))
                path.addLine(to: CGPoint(x: p2.x * scaleX, y: p2.y * scaleY))
                path.addLine(to: CGPoint(x: p3.x * scaleX, y: p3.y * scaleY))
                path.closeSubpath()
                context.fill(path, with: .color(color))
            }

            // Top-left facet — teal 600
            drawFacet(CGPoint(x: 50, y: 4), CGPoint(x: 18, y: 46), CGPoint(x: 50, y: 34),
                      color: Color.riffitTeal600)

            // Top-right facet — teal 400
            drawFacet(CGPoint(x: 50, y: 4), CGPoint(x: 82, y: 46), CGPoint(x: 50, y: 34),
                      color: Color.riffitTeal400)

            // Mid-left facet — primaryPressed (amber)
            drawFacet(CGPoint(x: 50, y: 34), CGPoint(x: 18, y: 46), CGPoint(x: 50, y: 54),
                      color: Color.riffitPrimaryPressed)

            // Mid-right facet — primary (gold)
            drawFacet(CGPoint(x: 50, y: 34), CGPoint(x: 82, y: 46), CGPoint(x: 50, y: 54),
                      color: Color.riffitPrimary)

            // Lower-left facet — teal 600
            drawFacet(CGPoint(x: 50, y: 54), CGPoint(x: 18, y: 46), CGPoint(x: 32, y: 76),
                      color: Color.riffitTeal600)

            // Lower-right facet — teal 900
            drawFacet(CGPoint(x: 50, y: 54), CGPoint(x: 82, y: 46), CGPoint(x: 68, y: 76),
                      color: Color.riffitTeal900)

            // Bottom-left facet — teal 600, 70% opacity
            drawFacet(CGPoint(x: 50, y: 54), CGPoint(x: 32, y: 76), CGPoint(x: 50, y: 104),
                      color: Color.riffitTeal600.opacity(0.7))

            // Bottom-right facet — teal 900
            drawFacet(CGPoint(x: 50, y: 54), CGPoint(x: 68, y: 76), CGPoint(x: 50, y: 104),
                      color: Color.riffitTeal900)
        }
    }
}

// MARK: - Story Card

/// A card showing a story in the Storybank list.
struct StoryCard: View {
    let story: Story
    let countsLabel: String
    let avatarUrl: String?
    let avatarInitial: String

    var body: some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            // Title + status badge
            HStack {
                Text(story.title)
                    .font(RF.heading)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .lineLimit(2)

                Spacer()

                StoryStatusBadge(status: story.status)
            }

            // Asset/reference counts
            Text(countsLabel)
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextSecondary)

            // Timestamp + author avatar
            HStack {
                Text(story.updatedAt.relativeTimestamp)
                    .font(RF.meta)
                    .foregroundStyle(Color.riffitTextTertiary)

                Spacer()

                cardAvatar
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
    }

    @ViewBuilder
    private var cardAvatar: some View {
        if let urlString = avatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                avatarFallback
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            avatarFallback
        }
    }

    private var avatarFallback: some View {
        Text(avatarInitial)
            .font(RF.caption)
            .foregroundStyle(Color.riffitTextPrimary)
            .frame(width: 28, height: 28)
            .background(Color.riffitTeal600)
            .clipShape(Circle())
    }
}

// MARK: - Story Status Badge

/// Capsule badge showing draft/ready status.
struct StoryStatusBadge: View {
    let status: Story.Status

    var body: some View {
        Text(status.label)
            .font(RF.tag)
            .foregroundStyle(foregroundColor)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch status {
        case .draft:
            return Color.riffitTextSecondary
        case .ready:
            return Color.riffitPrimary
        case .archived:
            return Color.riffitTextTertiary
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .draft:
            return Color.riffitSurface
        case .ready:
            return Color.riffitPrimaryTint
        case .archived:
            return Color.riffitSurface
        }
    }
}

extension Story.Status {
    var label: String {
        switch self {
        case .draft: return "Draft"
        case .ready: return "Ready"
        case .archived: return "Archived"
        }
    }
}

// MARK: - Story Folder Row

/// Displays a folder in the Storybank list.
struct StoryFolderRow: View {
    let folder: StoryFolder
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

// MARK: - Story Folder Drop Target

/// Wraps a StoryFolderRow with drop-target behavior so stories
/// can be dragged onto a folder to organize them.
struct StoryFolderDropTarget: View {
    let folder: StoryFolder
    @ObservedObject var viewModel: StorybankViewModel
    @State private var isTargeted: Bool = false

    var body: some View {
        NavigationLink(value: folder) {
            StoryFolderRow(
                folder: folder,
                count: viewModel.stories(in: folder).count
            )
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
                  let storyId = UUID(uuidString: idString),
                  viewModel.stories.contains(where: { $0.id == storyId })
            else { return false }
            viewModel.moveStory(storyId, to: folder.id)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}

// MARK: - Story Folder Detail View

/// Shows the stories inside a folder. Supports renaming, deleting
/// the folder, and removing stories from it.
struct StoryFolderDetailView: View {
    let folder: StoryFolder
    @ObservedObject var viewModel: StorybankViewModel
    @EnvironmentObject var appState: AppState

    private var folderAvatarInitial: String {
        if let name = appState.currentUser?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty, let first = name.first {
            return String(first).uppercased()
        }
        if let first = appState.currentUser?.email.first {
            return String(first).uppercased()
        }
        return "?"
    }

    @State private var showRenameAlert: Bool = false
    @State private var renameText: String = ""
    @State private var showDeleteConfirm: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            let folderStories = viewModel.stories(in: folder)

            if folderStories.isEmpty {
                VStack(spacing: RS.sm) {
                    Text("No stories in this folder")
                        .font(RF.bodyMd)
                        .foregroundStyle(Color.riffitTextTertiary)

                    Text("Drag stories here to organize them.")
                        .font(RF.caption)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, RS.lg)
            } else {
                ScrollView {
                    LazyVStack(spacing: RS.smPlus) {
                        ForEach(folderStories) { story in
                            NavigationLink(value: story) {
                                StoryCard(story: story, countsLabel: viewModel.countsLabel(for: story.id), avatarUrl: appState.currentUser?.avatarUrl, avatarInitial: folderAvatarInitial)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    viewModel.moveStory(story.id, to: nil)
                                } label: {
                                    Label("Remove from Folder", systemImage: "folder.badge.minus")
                                }
                            }
                            .draggable(story.id.uuidString)
                        }
                    }
                    .padding(.horizontal, RS.md)
                    .padding(.vertical, RS.smPlus)
                }
                .navigationDestination(for: Story.self) { story in
                    StoryDetailView(story: story, viewModel: viewModel)
                }
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        renameText = folder.name
                        showRenameAlert = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Folder", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .riffitModal(isPresented: $showRenameAlert) {
            RiffitInputModal(
                title: "Rename Folder",
                placeholder: "Folder name",
                actionLabel: "Save",
                text: $renameText,
                onCancel: {
                    showRenameAlert = false
                },
                onAction: { name in
                    viewModel.renameFolder(folder, to: name)
                    showRenameAlert = false
                }
            )
        }
        .riffitModal(isPresented: $showDeleteConfirm) {
            RiffitConfirmModal(
                title: "Delete Folder?",
                message: "Stories inside will be moved to Unfiled.",
                actionLabel: "Delete",
                onCancel: {
                    showDeleteConfirm = false
                },
                onAction: {
                    viewModel.deleteFolder(folder)
                    showDeleteConfirm = false
                    dismiss()
                }
            )
        }
    }
}
