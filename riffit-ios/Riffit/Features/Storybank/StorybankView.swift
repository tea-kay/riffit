import SwiftUI

/// The Storybank tab — the creator's workspace for organizing stories.
/// Each story collects assets (voice notes, video, images, text) and
/// references to inspiration videos from the Library.
struct StorybankView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: StorybankViewModel
    @State private var showNewStoryAlert: Bool = false
    @State private var newStoryTitle: String = ""
    @State private var newStoryFolderId: UUID?
    @State private var showNewFolderAlert: Bool = false
    @State private var newFolderName: String = ""
    @State private var showActionSheet: Bool = false
    @State private var showLeaveConfirm: Bool = false
    @State private var collaboratorToLeave: StoryCollaborator?
    @State private var selectedSegment: StorybankSegment = .myStories
    @State private var selectedFolderFilter: UUID?
    @State private var showRenameFolderAlert: Bool = false
    @State private var renameFolderTarget: StoryFolder?
    @State private var renameFolderText: String = ""
    @State private var showDeleteFolderConfirm: Bool = false
    @State private var deleteFolderTarget: StoryFolder?
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

            if !viewModel.hasLoadedOnce {
                // Blank background while data loads (<200ms) — avoids empty state flicker
                Color.clear
            } else if viewModel.isEmpty && !viewModel.hasSharedContent {
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
                    newStoryFolderId = nil
                    showNewStoryAlert = false
                },
                onAction: { title in
                    Task {
                        await viewModel.createStory(title: title, userId: appState.currentUser?.id)
                        // Auto-assign to folder if triggered from a folder empty state
                        if let folderId = newStoryFolderId,
                           let story = viewModel.stories.first {
                            await viewModel.moveStory(story.id, to: folderId)
                        }
                    }
                    newStoryFolderId = nil
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
                    Task { await viewModel.createFolder(name: name, userId: appState.currentUser?.id) }
                    showNewFolderAlert = false
                }
            )
        }
        .task {
            guard !viewModel.hasLoadedOnce else { return }
            await viewModel.fetchStories(userId: appState.currentUser?.id)
        }
        // Safety net: if .task fired before currentUser was set (nil userId),
        // retry when currentUser arrives. With the RootView three-way branch
        // this should rarely fire, but it's cheap insurance.
        .onChange(of: appState.currentUser?.id) { _, newId in
            if let newId, !viewModel.hasLoadedOnce {
                Task { await viewModel.fetchStories(userId: newId) }
            }
        }
    }

    // MARK: - Story List

    private var storyList: some View {
        ScrollView {
            LazyVStack(spacing: RS.smPlus) {
                // Segmented control — only when shared content exists
                if viewModel.hasSharedContent {
                    StorybankSegmentedControl(
                        selection: $selectedSegment,
                        hasPending: !viewModel.pendingInvites.isEmpty
                    )
                    .padding(.bottom, RS.xs)
                }

                if selectedSegment == .myStories || !viewModel.hasSharedContent {
                    myStoriesContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    sharedSegmentContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
            .padding(.horizontal, RS.md)
            .padding(.vertical, RS.smPlus)
        }
        .refreshable {
            await viewModel.fetchStories(userId: appState.currentUser?.id)
        }
        .navigationDestination(for: Story.self) { story in
            StoryDetailView(story: story, viewModel: viewModel)
        }
        // Folder rename modal
        .riffitModal(isPresented: $showRenameFolderAlert) {
            RiffitInputModal(
                title: "Rename Folder",
                placeholder: "Folder name",
                actionLabel: "Save",
                text: $renameFolderText,
                onCancel: {
                    showRenameFolderAlert = false
                    renameFolderTarget = nil
                },
                onAction: { name in
                    if let folder = renameFolderTarget {
                        Task { await viewModel.renameFolder(folder, to: name) }
                    }
                    showRenameFolderAlert = false
                    renameFolderTarget = nil
                }
            )
        }
        // Folder delete confirmation
        .riffitModal(isPresented: $showDeleteFolderConfirm) {
            RiffitConfirmationModal(
                title: "Delete \(deleteFolderTarget?.name ?? "folder")?",
                message: "Stories in this folder won't be deleted — they'll move to unfiled.",
                confirmLabel: "Delete",
                isDestructive: true,
                onConfirm: {
                    if let folder = deleteFolderTarget {
                        if selectedFolderFilter == folder.id {
                            selectedFolderFilter = nil
                        }
                        Task { await viewModel.deleteFolder(folder) }
                    }
                    showDeleteFolderConfirm = false
                    deleteFolderTarget = nil
                },
                onCancel: {
                    showDeleteFolderConfirm = false
                    deleteFolderTarget = nil
                }
            )
        }
        .riffitModal(isPresented: $showLeaveConfirm) {
            RiffitConfirmationModal(
                title: "Leave Story?",
                message: "You will lose access to this story.",
                confirmLabel: "Leave",
                isDestructive: true,
                onConfirm: {
                    if let collab = collaboratorToLeave {
                        Task { await viewModel.leaveStory(collab) }
                    }
                    collaboratorToLeave = nil
                    showLeaveConfirm = false
                },
                onCancel: {
                    collaboratorToLeave = nil
                    showLeaveConfirm = false
                }
            )
        }
    }

    // MARK: - My Stories Content

    /// Stories filtered by the selected folder pill.
    /// "All" (nil) shows everything; a specific folder shows only its stories.
    private var filteredMyStories: [Story] {
        let owned = viewModel.stories.filter { !viewModel.isSharedStory($0.id) }
        if let folderId = selectedFolderFilter {
            return owned.filter { viewModel.storyFolderMap[$0.id] == folderId }
        }
        return owned
    }

    @ViewBuilder
    private var myStoriesContent: some View {
        // Folder dropdown — shown when folders exist, UNLESS the folder empty state
        // is active (which renders its own overlaid folderPicker to avoid pushing content down)
        let isFolderEmptyState = selectedFolderFilter != nil && filteredMyStories.isEmpty
        if !viewModel.folders.isEmpty && !isFolderEmptyState {
            folderPicker
        }

        // "UNFILED" section header — only when "All" is selected and folders exist
        let unfiled = viewModel.unfiledStories
        if selectedFolderFilter == nil && !viewModel.folders.isEmpty && !unfiled.isEmpty {
            let filedStories = filteredMyStories.filter { viewModel.storyFolderMap[$0.id] != nil }
            if !filedStories.isEmpty {
                // Show filed stories first
                ForEach(filedStories) { story in
                    storyCardLink(story)
                }

                Text("Unfiled")
                    .font(RF.tag)
                    .textCase(.uppercase)
                    .tracking(0.08 * 12)
                    .foregroundStyle(Color.riffitTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, RS.sm)

                ForEach(unfiled) { story in
                    storyCardLink(story)
                }
            } else {
                // Only unfiled stories exist
                ForEach(unfiled) { story in
                    storyCardLink(story)
                }
            }
        } else if selectedFolderFilter != nil && filteredMyStories.isEmpty {
            // Filtered empty state — folder picker is overlaid at top so it
            // doesn't push the centered content down vs the Ideas empty state
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Spacer()

                    // Illustration — fixed 140pt height to match Ideas and Storybank empty states
                    FolderEmptyRipple()
                        .frame(width: 180, height: 140)

                    Spacer().frame(height: RS.lg)  // 24pt

                    Text("Nothing in here yet")
                        .font(RF.heading)
                        .foregroundStyle(Color.riffitTextPrimary)

                    Spacer().frame(height: RS.sm)  // 8pt

                    Text("Move a story here or start a new one.")
                        .font(RF.caption)
                        .foregroundStyle(Color.riffitTextSecondary)

                    Spacer().frame(height: RS.lg)  // 24pt

                    RiffitButton(title: "Start a new story", variant: .ghostGold) {
                        newStoryTitle = ""
                        newStoryFolderId = selectedFolderFilter
                        showNewStoryAlert = true
                    }
                    .padding(.horizontal, RS.xl2)

                    Spacer()
                }

                // Folder picker pinned to top, overlaid so it doesn't
                // affect the vertical centering of the empty state
                folderPicker
            }
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical) { length, _ in length }
        } else if filteredMyStories.isEmpty {
            // "All stories" selected but no owned stories exist —
            // show the main empty state centered below the folder picker
            VStack(spacing: 0) {
                Spacer()

                GemIllustration()
                    .frame(width: 100, height: 140)

                Spacer().frame(height: RS.lg)  // 24pt

                Text(colorScheme == .dark
                     ? "Every story needs a spark."
                     : "Your story starts here.")
                    .font(RF.heading)
                    .foregroundStyle(Color.riffitTextPrimary)

                Spacer().frame(height: RS.sm)  // 8pt

                Text("Start building your first story.")
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextSecondary)

                Spacer().frame(height: RS.lg)  // 24pt

                RiffitButton(title: "Start a new story", variant: .ghostGold) {
                    newStoryTitle = ""
                    showNewStoryAlert = true
                }
                .padding(.horizontal, RS.xl2)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical) { length, _ in length }
        } else {
            ForEach(filteredMyStories) { story in
                storyCardLink(story)
            }
        }
    }

    /// A single story card with navigation link and context menu.
    private func storyCardLink(_ story: Story) -> some View {
        NavigationLink(value: story) {
            StoryCard(story: story, countsLabel: viewModel.countsLabel(for: story.id), avatarImage: appState.avatarImage, avatarInitial: userAvatarInitial)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !viewModel.folders.isEmpty {
                // "Move to folder" submenu
                Menu {
                    ForEach(viewModel.folders) { folder in
                        Button {
                            Task { await viewModel.moveStory(story.id, to: folder.id) }
                        } label: {
                            Label(folder.name, systemImage: viewModel.storyFolderMap[story.id] == folder.id ? "checkmark.circle.fill" : "folder")
                        }
                    }

                    if viewModel.storyFolderMap[story.id] != nil {
                        Divider()
                        Button {
                            Task { await viewModel.moveStory(story.id, to: nil) }
                        } label: {
                            Label("Remove from folder", systemImage: "folder.badge.minus")
                        }
                    }
                } label: {
                    Label("Move to folder", systemImage: "folder")
                }
            }
        }
    }

    // MARK: - Folder Picker

    /// The name shown in the folder picker label.
    private var folderPickerLabel: String {
        if let folderId = selectedFolderFilter,
           let folder = viewModel.folders.first(where: { $0.id == folderId }) {
            return folder.name
        }
        return "All stories"
    }

    private var folderPicker: some View {
        Menu {
            // "All stories" option
            Button {
                selectedFolderFilter = nil
            } label: {
                if selectedFolderFilter == nil {
                    Label("All stories", systemImage: "checkmark")
                } else {
                    Text("All stories")
                }
            }

            Divider()

            // Folder options with inline rename/delete via context menu
            ForEach(viewModel.folders) { folder in
                let isActive = selectedFolderFilter == folder.id

                Button {
                    selectedFolderFilter = folder.id
                } label: {
                    if isActive {
                        Label(folder.name, systemImage: "checkmark")
                    } else {
                        Text(folder.name)
                    }
                }
            }

            Divider()

            // New folder action
            Button {
                newFolderName = ""
                showNewFolderAlert = true
            } label: {
                Label("New Folder", systemImage: "plus")
            }

            // Folder management section — only when a folder is selected
            if let folderId = selectedFolderFilter,
               let folder = viewModel.folders.first(where: { $0.id == folderId }) {
                Divider()

                Button {
                    renameFolderTarget = folder
                    renameFolderText = folder.name
                    showRenameFolderAlert = true
                } label: {
                    Label("Rename \(folder.name)", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    deleteFolderTarget = folder
                    showDeleteFolderConfirm = true
                } label: {
                    Label("Delete \(folder.name)", systemImage: "trash")
                }
            }
        } label: {
            HStack(spacing: RS.xs) {
                Text(folderPickerLabel)
                    .font(RF.body(14, weight: .medium))
                    .foregroundStyle(
                        selectedFolderFilter == nil
                            ? Color.riffitTextSecondary
                            : Color.riffitTextPrimary
                    )

                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.riffitTextTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Shared Segment Content

    @ViewBuilder
    private var sharedSegmentContent: some View {
        // Pending section
        if !viewModel.pendingInvites.isEmpty {
            pendingSection
        }

        // Active section
        if !viewModel.acceptedSharedStories.isEmpty {
            activeSection
        }

        // Safety net — segment is normally hidden when empty
        if viewModel.pendingInvites.isEmpty && viewModel.acceptedSharedStories.isEmpty {
            if viewModel.hasLoadedSharedOnce {
                Text("No shared stories yet")
                    .font(RF.displayItalic(15))
                    .foregroundStyle(Color.riffitTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RS.xl2)
            } else {
                ProgressView()
                    .tint(Color.riffitPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RS.xl2)
            }
        }
    }

    @ViewBuilder
    private var pendingSection: some View {
        // Section label + count badge
        HStack(spacing: RS.sm) {
            Text("PENDING")
                .font(RF.body(11, weight: .medium))
                .tracking(0.06 * 11)
                .foregroundStyle(Color.riffitPrimary)

            Text("\(viewModel.pendingInvites.count)")
                .font(RF.meta)
                .foregroundStyle(Color.riffitPrimary)
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(Color.riffitPrimaryTint)
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.top, RS.sm)

        ForEach(viewModel.pendingInvites) { invite in
            PendingInviteCard(
                collaborator: invite,
                inviterDisplayName: invite.invitedBy.flatMap { viewModel.collaboratorUserInfo[$0]?.displayName } ?? "Someone",
                inviterAvatarUrl: invite.invitedBy.flatMap { viewModel.collaboratorUserInfo[$0]?.avatarUrl },
                storyTitle: viewModel.stories.first(where: { $0.id == invite.storyId })?.title ?? "Untitled Story",
                countsLabel: viewModel.countsLabel(for: invite.storyId),
                onAccept: {
                    Task { await viewModel.acceptInvite(invite) }
                },
                onDecline: {
                    Task { await viewModel.declineInvite(invite) }
                }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var activeSection: some View {
        Text("ACTIVE")
            .font(RF.body(11, weight: .medium))
            .tracking(0.06 * 11)
            .foregroundStyle(Color.riffitTeal600)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, RS.sm)

        ForEach(viewModel.acceptedSharedStories) { collab in
            if let story = viewModel.stories.first(where: { $0.id == collab.storyId }) {
                let ownerInfo = viewModel.collaboratorUserInfo[story.creatorProfileId]
                NavigationLink(value: story) {
                    SharedStoryCard(
                        story: story,
                        collaborator: collab,
                        countsLabel: viewModel.countsLabel(for: story.id),
                        hasUnread: viewModel.hasUnreadNotes(for: story.id),
                        ownerDisplayName: ownerInfo?.displayName ?? "Creator",
                        ownerAvatarUrl: ownerInfo?.avatarUrl
                    )
                }
                .buttonStyle(CardPressStyle())
                .contextMenu {
                    Button(role: .destructive) {
                        collaboratorToLeave = collab
                        showLeaveConfirm = true
                    } label: {
                        Label("Leave story", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ZStack {
            storybankGridBackground

            VStack(spacing: 0) {
                Spacer()

                // Illustration — fixed 140pt frame so both tabs align
                GemIllustration()
                    .frame(width: 100, height: 140)

                Spacer().frame(height: RS.lg)  // 24pt

                Text(colorScheme == .dark
                     ? "Every story needs a spark."
                     : "Your story starts here.")
                    .font(RF.heading)
                    .foregroundStyle(Color.riffitTextPrimary)

                Spacer().frame(height: RS.sm)  // 8pt

                Text("Start building your first story.")
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextSecondary)

                Spacer().frame(height: RS.lg)  // 24pt

                RiffitButton(title: "Start a new story", variant: .ghostGold) {
                    newStoryTitle = ""
                    showNewStoryAlert = true
                }
                .padding(.horizontal, RS.xl2)

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
    let avatarImage: UIImage?
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

    private var cardAvatar: some View {
        AvatarView(image: avatarImage, fallbackInitial: avatarInitial, size: 28)
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
                                StoryCard(story: story, countsLabel: viewModel.countsLabel(for: story.id), avatarImage: appState.avatarImage, avatarInitial: folderAvatarInitial)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    Task { await viewModel.moveStory(story.id, to: nil) }
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
                    Task { await viewModel.renameFolder(folder, to: name) }
                    showRenameAlert = false
                }
            )
        }
        .riffitModal(isPresented: $showDeleteConfirm) {
            RiffitConfirmationModal(
                title: "Delete \(folder.name)?",
                message: "Stories in this folder won't be deleted — they'll move to unfiled.",
                confirmLabel: "Delete",
                isDestructive: true,
                onConfirm: {
                    Task { await viewModel.deleteFolder(folder) }
                    showDeleteConfirm = false
                    dismiss()
                },
                onCancel: {
                    showDeleteConfirm = false
                }
            )
        }
    }
}

// MARK: - Shared Story Card

/// A story card for the "Shared" segment.
/// Shows owner attribution, role pill, and unread gold dot.
struct SharedStoryCard: View {
    let story: Story
    let collaborator: StoryCollaborator
    let countsLabel: String
    let hasUnread: Bool
    let ownerDisplayName: String
    let ownerAvatarUrl: String?

    var body: some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            // Title + role pill
            HStack {
                Text(story.title)
                    .font(RF.heading)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .lineLimit(2)

                Spacer()

                // Role pill — teal tint, trailing
                Text(collaborator.role.displayName)
                    .font(RF.tag)
                    .foregroundStyle(rolePillTextColor)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(rolePillBackground)
                    .clipShape(Capsule())
            }

            // Owner row: 20pt avatar + @ownerName
            HStack(spacing: RS.xs) {
                ownerAvatar

                Text("@\(ownerDisplayName)")
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextSecondary)
            }

            // Counts + timestamp + unread dot
            HStack {
                Text(countsLabel)
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextSecondary)

                Spacer()

                // Unread gold dot
                if hasUnread {
                    Circle()
                        .fill(Color.riffitPrimary)
                        .frame(width: 7, height: 7)
                }

                Text(story.updatedAt.relativeTimestamp)
                    .font(RF.meta)
                    .foregroundStyle(Color.riffitTextTertiary)
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
    private var ownerAvatar: some View {
        if let urlString = ownerAvatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                ownerAvatarFallback
            }
            .frame(width: 20, height: 20)
            .clipShape(Circle())
            .id(urlString)
        } else {
            ownerAvatarFallback
        }
    }

    private var ownerAvatarFallback: some View {
        Text(String(ownerDisplayName.first ?? Character("?")))
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Color.riffitTextPrimary)
            .frame(width: 20, height: 20)
            .background(Color.riffitTeal600)
            .clipShape(Circle())
    }

    private var rolePillTextColor: Color {
        switch collaborator.role {
        case .editor, .collaborator:
            return Color.riffitTeal400
        case .viewer, .commenter:
            return Color.riffitTextSecondary
        default:
            return Color.riffitTextSecondary
        }
    }

    private var rolePillBackground: Color {
        switch collaborator.role {
        case .editor, .collaborator:
            return Color.riffitTealTint
        case .viewer, .commenter:
            return Color.riffitElevated
        default:
            return Color.riffitElevated
        }
    }
}

// MARK: - Pending Invite Card

/// Rich invite card with real inviter info, story title, and Join/Decline actions.
/// Gold-tinted border distinguishes it from regular story cards.
struct PendingInviteCard: View {
    let collaborator: StoryCollaborator
    let inviterDisplayName: String
    let inviterAvatarUrl: String?
    let storyTitle: String
    let countsLabel: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RS.smPlus) {
            // Top row: avatar + "@name invited you" + timestamp
            HStack(spacing: RS.sm) {
                inviterAvatar

                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(inviterDisplayName) invited you")
                        .font(RF.bodySm)
                        .foregroundStyle(Color.riffitTextSecondary)

                    Text(collaborator.createdAt.relativeTimestamp)
                        .font(RF.meta)
                        .foregroundStyle(Color.riffitTextTertiary)
                }

                Spacer()
            }

            // Story title
            Text(storyTitle)
                .font(RF.display(17))
                .foregroundStyle(Color.riffitTextPrimary)
                .lineLimit(2)

            // Counts
            if !countsLabel.isEmpty {
                Text(countsLabel)
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextTertiary)
            }

            // Action buttons
            HStack(spacing: RS.sm) {
                // "Join story" — primary gold fill
                Button(action: onAccept) {
                    Text("Join story")
                        .font(RF.displayMedium(14))
                        .foregroundStyle(Color.riffitOnPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color.riffitPrimary)
                        .cornerRadius(RR.button)
                }
                .buttonStyle(.plain)

                // "Decline" — transparent with border
                Button(action: onDecline) {
                    Text("Decline")
                        .font(RF.displayMedium(14))
                        .foregroundStyle(Color.riffitTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: RR.button)
                                .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RS.md)
        .background(Color.riffitSurface)
        .cornerRadius(RR.card)
        .overlay(
            RoundedRectangle(cornerRadius: RR.card)
                .stroke(Color.riffitPrimary.opacity(0.25), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var inviterAvatar: some View {
        if let urlString = inviterAvatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                inviterAvatarFallback
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .id(urlString)
        } else {
            inviterAvatarFallback
        }
    }

    private var inviterAvatarFallback: some View {
        Text(String(inviterDisplayName.first ?? Character("?")))
            .font(RF.caption)
            .foregroundStyle(Color.riffitTextPrimary)
            .frame(width: 32, height: 32)
            .background(Color.riffitTeal600)
            .clipShape(Circle())
    }
}

// MARK: - Segmented Control

/// Which segment is active in the Storybank view.
enum StorybankSegment {
    case myStories
    case shared
}

/// Custom segmented control matching the Riffit design system.
/// Shows "My stories" and "Shared" tabs with a gold notification dot
/// on the Shared segment when pending invites exist.
struct StorybankSegmentedControl: View {
    @Binding var selection: StorybankSegment
    let hasPending: Bool

    var body: some View {
        HStack(spacing: 0) {
            segmentButton(.myStories, label: "My stories")
            segmentButton(.shared, label: "Shared", showDot: hasPending)
        }
        .padding(3)
        .background(Color.riffitSurface)
        .cornerRadius(RR.button)
        .overlay(
            RoundedRectangle(cornerRadius: RR.button)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    private func segmentButton(
        _ segment: StorybankSegment,
        label: String,
        showDot: Bool = false
    ) -> some View {
        let isSelected = selection == segment

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = segment
            }
        } label: {
            HStack(spacing: RS.xs) {
                Text(label)
                    .font(RF.bodyMd)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(
                        isSelected
                            ? Color.riffitTextPrimary
                            : Color.riffitTextSecondary
                    )

                if showDot {
                    Circle()
                        .fill(Color.riffitPrimary)
                        .frame(width: 7, height: 7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, RS.sm)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: RR.button - 3)
                            .fill(Color.riffitPrimaryTint)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Press Style

/// Tap feedback for tappable cards — subtle scale on press.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Folder Empty Ripple Illustration

/// Concentric ripple rings with a gold drop point — used for filtered
/// folder empty states. Transparent background, decorative only.
struct FolderEmptyRipple: View {
    var body: some View {
        Canvas { context, size in
            let midX = size.width / 2
            let midY = size.height / 2

            // ── Ripple rings — elliptical, radiating outward ──
            struct Ring {
                let rx: CGFloat
                let ry: CGFloat
                let color: Color
                let lineWidth: CGFloat
                let opacity: Double
            }

            // Scaled to fill 180×140 frame proportionally
            let rings: [Ring] = [
                // Outermost — teal 900
                Ring(rx: 160, ry: 100, color: .riffitTeal900, lineWidth: 0.5, opacity: 0.15),
                // Middle — teal 600
                Ring(rx: 126, ry: 78, color: .riffitTeal600, lineWidth: 0.6, opacity: 0.2),
                Ring(rx: 94, ry: 58, color: .riffitTeal600, lineWidth: 0.8, opacity: 0.3),
                // Inner — teal 400
                Ring(rx: 64, ry: 40, color: .riffitTeal400, lineWidth: 1.0, opacity: 0.45),
                Ring(rx: 36, ry: 22, color: .riffitTeal400, lineWidth: 1.2, opacity: 0.6),
            ]

            for ring in rings {
                let rect = CGRect(
                    x: midX - ring.rx / 2,
                    y: midY - ring.ry / 2,
                    width: ring.rx,
                    height: ring.ry
                )
                let path = Path(ellipseIn: rect)
                context.stroke(
                    path,
                    with: .color(ring.color.opacity(ring.opacity)),
                    lineWidth: ring.lineWidth
                )
            }

            // ── Teal accent dots on the ripple paths ──
            let accentDots: [(x: CGFloat, y: CGFloat, opacity: Double)] = [
                (midX - 58, midY - 18, 0.25),
                (midX + 54, midY + 22, 0.2),
                (midX - 32, midY + 26, 0.3),
                (midX + 68, midY - 10, 0.2),
            ]
            for dot in accentDots {
                let dotRect = CGRect(x: dot.x - 1.5, y: dot.y - 1.5, width: 3, height: 3)
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(Color.riffitTeal400.opacity(dot.opacity))
                )
            }

            // ── Gold glow — concentric soft circles ──
            let outerGlow = CGRect(x: midX - 20, y: midY - 20, width: 40, height: 40)
            context.fill(Path(ellipseIn: outerGlow), with: .color(Color.riffitPrimary.opacity(0.04)))

            let innerGlow = CGRect(x: midX - 12, y: midY - 12, width: 24, height: 24)
            context.fill(Path(ellipseIn: innerGlow), with: .color(Color.riffitPrimary.opacity(0.08)))

            // ── Center drop — gold circle ──
            let dropOuter = CGRect(x: midX - 5, y: midY - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: dropOuter), with: .color(Color.riffitPrimary.opacity(0.8)))

            let dropInner = CGRect(x: midX - 2.5, y: midY - 2.5, width: 5, height: 5)
            context.fill(Path(ellipseIn: dropInner), with: .color(Color.riffitPrimary))

            // ── Star accents ✦ ──
            let starFont = Font.system(size: 10, weight: .bold)
            // Gold star — upper right
            context.draw(
                Text("✦").font(starFont).foregroundColor(Color.riffitPrimary.opacity(0.3)),
                at: CGPoint(x: midX + 80, y: midY - 42)
            )
            // Teal star — lower left
            context.draw(
                Text("✦").font(starFont).foregroundColor(Color.riffitTeal400.opacity(0.25)),
                at: CGPoint(x: midX - 76, y: midY + 38)
            )
        }
    }
}
