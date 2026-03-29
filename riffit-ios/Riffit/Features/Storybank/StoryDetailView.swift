import SwiftUI

/// Identifiable wrapper for a URL, used to drive the share sheet binding.
private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// Detail view for a single Story. Two sections:
/// 1. My Assets — voice notes, video, images, text (reorderable via drag handles)
/// 2. References — links to inspiration videos from the Library
struct StoryDetailView: View {
    let story: Story
    @ObservedObject var viewModel: StorybankViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAddTextSheet: Bool = false
    @State private var showVoiceRecordSheet: Bool = false
    @State private var showImageAttachmentSheet: Bool = false
    @State private var showVideoAttachmentSheet: Bool = false
    @State private var playingVoiceAsset: StoryAsset?
    @State private var viewingImageAsset: StoryAsset?
    @State private var viewingVideoAsset: StoryAsset?
    @State private var showAddReferenceSheet: Bool = false
    @State private var showAddSectionModal: Bool = false
    @State private var newSectionName: String = ""
    @State private var editingAsset: StoryAsset?
    @State private var selectedVideo: InspirationVideo?
    @State private var showRenameModal: Bool = false
    @State private var renameText: String = ""
    @State private var renamingSection: AssetSection?
    @State private var renameSectionText: String = ""
    @State private var exportMessage: String?
    @State private var showExportAlert: Bool = false
    @State private var showPermissionAlert: Bool = false
    @State private var shareURL: URL?
    @State private var showStoryShareSheet: Bool = false
    @State private var newNoteText: String = ""
    @State private var editingNoteId: UUID?
    @State private var editingNoteText: String = ""
    @State private var showInviteSheet: Bool = false
    @State private var showManageCollaborators: Bool = false
    @State private var showLeaveConfirm: Bool = false
    @State private var showDeleteStoryConfirm: Bool = false
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var libraryViewModel: LibraryViewModel

    /// The current user's role on this story. If no collaborator record exists,
    /// checks ownership via creatorProfileId. Falls back to .viewer (safe default).
    private var userRole: CollaboratorRole {
        if let role = viewModel.currentUserRole(for: story.id, userId: appState.currentUser?.id) {
            return role
        }
        if story.creatorProfileId == appState.currentUser?.id {
            return .owner
        }
        return .viewer
    }

    /// Display name for note bubbles: username > full_name > email prefix
    private var noteDisplayName: String {
        if let username = appState.currentUser?.username?.trimmingCharacters(in: .whitespacesAndNewlines),
           !username.isEmpty {
            return username
        }
        if let name = appState.currentUser?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        if let email = appState.currentUser?.email {
            return email.components(separatedBy: "@").first ?? "You"
        }
        return "You"
    }

    /// Initials from the authenticated user for note avatar fallback
    private var noteAvatarInitial: String {
        if let name = appState.currentUser?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            let parts = name.split(separator: " ")
            if parts.count >= 2,
               let first = parts.first?.first,
               let last = parts.last?.first {
                return "\(first)\(last)".uppercased()
            }
            if let first = parts.first?.first {
                return String(first).uppercased()
            }
        }
        if let first = appState.currentUser?.email.first {
            return String(first).uppercased()
        }
        return "?"
    }

    /// Looks up the latest version of this story from the viewModel
    /// so the nav title reflects renames without re-entering the view.
    private var currentStory: Story {
        viewModel.stories.first(where: { $0.id == story.id }) ?? story
    }

    var body: some View {
        List {
            // MARK: Assets Section — flat list with interleaved section headers
            Section {
                let rows = viewModel.flatRows(for: story.id)
                if rows.isEmpty {
                    emptyAssetsState
                        .listRowBackground(Color.riffitBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: RS.md, bottom: 0, trailing: RS.md))
                } else {
                    ForEach(rows) { row in
                        switch row {
                        case .sectionHeader(let section):
                            SectionHeaderRow(
                                section: section,
                                showActions: userRole.canModifySections,
                                onRename: {
                                    renameSectionText = section.name
                                    renamingSection = section
                                },
                                onDelete: {
                                    Task { await viewModel.deleteSection(section) }
                                }
                            )
                            .listRowBackground(Color.riffitBackground)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(
                                top: RS.sm, leading: RS.md,
                                bottom: RS.xs, trailing: RS.md
                            ))

                        case .asset(let asset):
                            AssetRow(asset: asset)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    switch asset.assetType {
                                    case .text:
                                        editingAsset = asset
                                    case .voiceNote:
                                        playingVoiceAsset = asset
                                    case .image:
                                        viewingImageAsset = asset
                                    case .video:
                                        viewingVideoAsset = asset
                                    }
                                }
                                .contextMenu {
                                    if userRole.canDownloadAssets {
                                        Button {
                                            exportSingleAsset(asset)
                                        } label: {
                                            Label("Save to Device", systemImage: "square.and.arrow.down")
                                        }
                                    }

                                    if userRole.canModifyAssets {
                                        Button(role: .destructive) {
                                            Task { await viewModel.deleteAsset(asset) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                                .listRowBackground(Color.riffitBackground)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(
                                    top: RS.xs, leading: RS.md,
                                    bottom: RS.xs, trailing: RS.md
                                ))
                        }
                    }
                    .onMove { from, to in
                        guard userRole.canModifyAssets else { return }
                        // Reorder the flat array, then reassign sectionIDs
                        // based on which section header each asset falls under
                        var reordered = viewModel.flatRows(for: story.id)
                        reordered.move(fromOffsets: from, toOffset: to)
                        Task { await viewModel.applyFlatRowOrder(for: story.id, reordered: reordered) }
                    }
                    .moveDisabled(!userRole.canModifyAssets)
                    .deleteDisabled(true)
                }
            } header: {
                assetsHeader
            }

            // MARK: References Section
            Section {
                let _ = print("[StoryDetail] references for \(story.id): \(viewModel.references(for: story.id).count)")
                if viewModel.references(for: story.id).isEmpty {
                    emptyReferencesState
                        .listRowBackground(Color.riffitBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: RS.md, bottom: 0, trailing: RS.md))
                } else {
                    ForEach(viewModel.references(for: story.id)) { reference in
                        ReferenceCard(reference: reference, viewModel: viewModel)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Look up the linked video and navigate to its detail
                                if let video = libraryViewModel.videos.first(where: { $0.id == reference.inspirationVideoId }) {
                                    selectedVideo = video
                                }
                            }
                            .contextMenu {
                                if userRole.canModifyReferences {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteReference(reference) }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                            .listRowBackground(Color.riffitBackground)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(
                                top: RS.xs, leading: RS.md,
                                bottom: RS.xs, trailing: RS.md
                            ))
                    }
                    .onMove { from, to in
                        guard userRole.canModifyReferences else { return }
                        Task { await viewModel.moveReference(in: story.id, from: from, to: to) }
                    }
                    .moveDisabled(!userRole.canModifyReferences)
                    .deleteDisabled(true)
                }
            } header: {
                referencesHeader
            }

            // MARK: Notes Section
            Section {
                notesContent

                // Add note input row — only if role allows leaving notes
                if userRole.canLeaveNotes {
                    noteInputRow
                        .listRowBackground(Color.riffitBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: RS.xs, leading: RS.md,
                            bottom: RS.sm, trailing: RS.md
                        ))
                }
            } header: {
                notesHeader
            }

            // MARK: People Section
            Section {
                let collabs = viewModel.collaborators(for: story.id)
                ForEach(collabs) { collaborator in
                    CollaboratorRow(
                        collaborator: collaborator,
                        hasRolePermissions: true,
                        isOwnerView: userRole == .owner,
                        userDisplayName: collaborator.userId == appState.currentUser?.id
                            ? currentUserDisplayName
                            : viewModel.collaboratorDisplayName(for: collaborator, currentUserId: appState.currentUser?.id),
                        userAvatarUrl: collaborator.userId == appState.currentUser?.id
                            ? appState.currentUser?.avatarUrl
                            : viewModel.collaboratorAvatarUrl(for: collaborator, currentUserId: appState.currentUser?.id),
                        userAvatarImage: collaborator.userId == appState.currentUser?.id
                            ? appState.avatarImage
                            : nil,
                        onChangeRole: { newRole in
                            Task { await viewModel.updateCollaboratorRole(collaborator, to: newRole) }
                        },
                        onRemove: {
                            Task { await viewModel.removeCollaborator(collaborator) }
                        }
                    )
                    .onAppear {
                        // Cache user info for other users (not the current user)
                        if collaborator.userId != appState.currentUser?.id {
                            viewModel.cacheUserInfo(userId: collaborator.userId)
                        }
                    }
                    .listRowBackground(Color.riffitBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: RS.xs, leading: RS.md,
                        bottom: RS.xs, trailing: RS.md
                    ))
                }

                // "+ Invite" row — only for owners
                if userRole.canInviteCollaborators {
                    inviteRow
                        .listRowBackground(Color.riffitBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: RS.xs, leading: RS.md,
                            bottom: RS.sm, trailing: RS.md
                        ))
                }
            } header: {
                peopleHeader
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.riffitBackground)
        .environment(\.editMode, .constant(.active))
        .navigationTitle(currentStory.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    // Rename — owner + editor
                    if userRole.canRenameStory {
                        Button {
                            renameText = currentStory.title
                            showRenameModal = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                    }

                    // Archive — owner + editor
                    if userRole.canModifyAssets {
                        Button {
                            Task { await viewModel.updateStoryStatus(story, to: .archived) }
                            dismiss()
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }

                    Button {
                        showStoryShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    // Save All Assets — only if can download
                    if userRole.canDownloadAssets {
                        Button {
                            exportAllAssets()
                        } label: {
                            Label("Save All Assets", systemImage: "square.and.arrow.down.on.square")
                        }
                    }

                    // Duplicate — owner + editor
                    if userRole.canDuplicateStory {
                        Button {
                            Task { await viewModel.duplicateStory(story) }
                            dismiss()
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                    }

                    // Manage People — owner only
                    if userRole.canInviteCollaborators {
                        Button {
                            showManageCollaborators = true
                        } label: {
                            Label("Manage People", systemImage: "person.2")
                        }
                    }

                    // Compose — v2 AI brief generation, visually disabled
                    if userRole == .owner {
                        Button { } label: {
                            Label("Compose", systemImage: "sparkles")
                        }
                        .disabled(true)
                    }

                    Divider()

                    // Delete Story — owner only
                    if userRole.canDeleteStory {
                        Button(role: .destructive) {
                            showDeleteStoryConfirm = true
                        } label: {
                            Label("Delete Story", systemImage: "trash")
                        }
                    }

                    // Leave Story — non-owners
                    if userRole != .owner {
                        Button(role: .destructive) {
                            showLeaveConfirm = true
                        } label: {
                            Label("Leave Story", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .sheet(isPresented: $showAddTextSheet) {
            AddTextAssetSheet(storyId: story.id, viewModel: viewModel)
        }
        .sheet(isPresented: $showAddReferenceSheet) {
            AddReferenceView(story: story, viewModel: viewModel)
        }
        .fullScreenCover(item: $editingAsset) { asset in
            EditTextAssetView(asset: asset, viewModel: viewModel)
        }
        .sheet(item: $selectedVideo) { video in
            NavigationStack {
                InspirationDetailView(video: video, viewModel: libraryViewModel)
            }
        }
        .sheet(isPresented: $showVoiceRecordSheet) {
            VoiceNoteRecordSheet(storyId: story.id, viewModel: viewModel)
        }
        .sheet(isPresented: $showImageAttachmentSheet) {
            ImageAttachmentSheet(storyId: story.id, viewModel: viewModel)
        }
        .fullScreenCover(item: $playingVoiceAsset) { asset in
            VoiceNotePlayerView(asset: asset, viewModel: viewModel)
        }
        .fullScreenCover(item: $viewingImageAsset) { asset in
            ImageViewerView(asset: asset, viewModel: viewModel)
        }
        .sheet(isPresented: $showVideoAttachmentSheet) {
            VideoAttachmentSheet(storyId: story.id, viewModel: viewModel)
        }
        .fullScreenCover(item: $viewingVideoAsset) { asset in
            VideoPlayerView(asset: asset, viewModel: viewModel)
        }
        .sheet(isPresented: $showStoryShareSheet) {
            ShareSheet(items: [currentStory.title])
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteSheet(story: story, viewModel: viewModel)
        }
        .sheet(isPresented: $showManageCollaborators) {
            ManageCollaboratorsView(story: story, viewModel: viewModel)
        }
        .onAppear {
            // Load collaborator data from Supabase for the People section
            Task { await viewModel.fetchCollaborators(for: story.id) }

            let isOwner = story.creatorProfileId == appState.currentUser?.id
            if isOwner {
                Task { await viewModel.fetchInviteLinks(for: story.id) }
            } else {
                viewModel.updateLastViewed(for: story.id)
            }
        }
        .riffitModal(isPresented: $showLeaveConfirm) {
            RiffitConfirmationModal(
                title: "Leave Story?",
                message: "You will lose access to this story.",
                confirmLabel: "Leave",
                isDestructive: true,
                onConfirm: {
                    if let collab = viewModel.sharedCollaborations.first(where: { $0.storyId == story.id }) {
                        Task { await viewModel.leaveStory(collab) }
                    }
                    showLeaveConfirm = false
                    dismiss()
                },
                onCancel: {
                    showLeaveConfirm = false
                }
            )
        }
        .riffitModal(isPresented: $showDeleteStoryConfirm) {
            RiffitConfirmationModal(
                title: "Delete Story?",
                message: "This story and all its assets will be permanently deleted.",
                confirmLabel: "Delete",
                isDestructive: true,
                onConfirm: {
                    showDeleteStoryConfirm = false
                    // Await Supabase DELETE before dismiss so the .task re-fetch
                    // on StorybankView cannot resurrect the deleted story
                    Task {
                        await viewModel.deleteStory(story)
                        dismiss()
                    }
                },
                onCancel: {
                    showDeleteStoryConfirm = false
                }
            )
        }
        .riffitModal(isPresented: $showRenameModal) {
            RiffitInputModal(
                title: "Rename Story",
                placeholder: "Story name",
                actionLabel: "Save",
                text: $renameText,
                onCancel: {
                    showRenameModal = false
                },
                onAction: { name in
                    Task { await viewModel.updateStoryTitle(story, to: name) }
                    showRenameModal = false
                }
            )
        }
        .riffitModal(isPresented: $showAddSectionModal) {
            RiffitInputModal(
                title: "New Section",
                placeholder: "Section name",
                actionLabel: "Create",
                text: $newSectionName,
                onCancel: {
                    showAddSectionModal = false
                },
                onAction: { name in
                    Task { await viewModel.addSection(to: story.id, name: name) }
                    showAddSectionModal = false
                }
            )
        }
        .riffitModal(isPresented: Binding(
            get: { renamingSection != nil },
            set: { if !$0 { renamingSection = nil } }
        )) {
            RiffitInputModal(
                title: "Rename Section",
                placeholder: "Section name",
                actionLabel: "Save",
                text: $renameSectionText,
                onCancel: {
                    renamingSection = nil
                },
                onAction: { name in
                    if let section = renamingSection {
                        Task { await viewModel.renameSection(section, to: name) }
                    }
                    renamingSection = nil
                }
            )
        }
        .alert("Export Result", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage ?? "Done")
        }
        .alert("Photo Library Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Riffit needs photo library access to save assets. Enable it in Settings.")
        }
        .sheet(item: Binding(
            get: { shareURL.map { ShareItem(url: $0) } },
            set: { if $0 == nil { shareURL = nil } }
        )) { item in
            ShareSheet(items: [item.url])
        }
    }

    // MARK: - Export Helpers

    private func exportSingleAsset(_ asset: StoryAsset) {
        Task {
            let (result, url) = await AssetExportService.export(asset)

            switch result {
            case .success:
                if let url {
                    // Text asset — present share sheet
                    shareURL = url
                } else {
                    exportMessage = "Saved to device"
                    showExportAlert = true
                }
            case .permissionDenied:
                showPermissionAlert = true
            case .fileNotFound:
                exportMessage = "File not found — it may have been deleted"
                showExportAlert = true
            case .failed(let reason):
                exportMessage = "Export failed: \(reason)"
                showExportAlert = true
            }
        }
    }

    private func exportAllAssets() {
        Task {
            let allAssets = viewModel.assets(for: story.id)
            guard !allAssets.isEmpty else {
                exportMessage = "No assets to export"
                showExportAlert = true
                return
            }

            var saved = 0
            var skipped = 0
            var denied = false
            var textURLs: [URL] = []

            for asset in allAssets {
                let (result, url) = await AssetExportService.export(asset)

                switch result {
                case .success:
                    if let url {
                        textURLs.append(url)
                    }
                    saved += 1
                case .permissionDenied:
                    denied = true
                case .fileNotFound:
                    skipped += 1
                case .failed:
                    skipped += 1
                }
            }

            if denied {
                showPermissionAlert = true
                return
            }

            // If there are text files, share them via share sheet
            if !textURLs.isEmpty {
                shareURL = textURLs.first
            }

            var message = "Saved \(saved) asset\(saved == 1 ? "" : "s")"
            if skipped > 0 {
                message += ", \(skipped) skipped"
            }
            exportMessage = message
            showExportAlert = true
        }
    }

    // MARK: - Section Headers

    private var assetsHeader: some View {
        HStack {
            Text(userRole == .owner ? "My Assets" : "Assets")
                .font(RF.tag)
                .textCase(.uppercase)
                .tracking(0.08 * 12)
                .foregroundStyle(Color.riffitTextTertiary)

            Spacer()

            // Add section + add asset buttons — only for roles that can modify
            if userRole.canModifyAssets {
                // Add section button
                Button {
                    newSectionName = ""
                    showAddSectionModal = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.body)
                        .foregroundStyle(Color.riffitTeal400)
                }

                // Add asset button
                Menu {
                    Button {
                        showVoiceRecordSheet = true
                    } label: {
                        Label("Voice Note", systemImage: "waveform")
                    }

                    Button {
                        showVideoAttachmentSheet = true
                    } label: {
                        Label("Video", systemImage: "video")
                    }

                    Button {
                        showImageAttachmentSheet = true
                    } label: {
                        Label("Image", systemImage: "photo")
                    }

                    Button {
                        showAddTextSheet = true
                    } label: {
                        Label("Text", systemImage: "text.alignleft")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .padding(.bottom, RS.xs)
    }

    private var referencesHeader: some View {
        HStack {
            Text("References")
                .font(RF.tag)
                .textCase(.uppercase)
                .tracking(0.08 * 12)
                .foregroundStyle(Color.riffitTextTertiary)

            Spacer()

            if userRole.canModifyReferences {
                Button {
                    showAddReferenceSheet = true
                } label: {
                    HStack(spacing: RS.xs) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add from Library")
                            .font(RF.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .padding(.top, RS.md)
        .padding(.bottom, RS.xs)
    }

    // MARK: - Empty States

    private var emptyAssetsState: some View {
        VStack(spacing: RS.sm) {
            Text("No assets yet")
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextTertiary)

            Text("Add voice notes, video, images, or text.")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RS.lg)
    }

    private var emptyReferencesState: some View {
        VStack(spacing: RS.sm) {
            Text("No references yet")
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextTertiary)

            Text("Pull ideas from your Library.")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RS.lg)
    }

    // MARK: - Notes

    /// Extracted from body to reduce type-checker complexity.
    @ViewBuilder
    private var notesContent: some View {
        let storyNotes = viewModel.notes(for: story.id)
        if storyNotes.isEmpty {
            emptyNotesState
                .listRowBackground(Color.riffitBackground)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: RS.md, bottom: 0, trailing: RS.md))
        } else {
            ForEach(storyNotes) { note in
                noteBubbleRow(for: note)
                    .listRowBackground(Color.riffitBackground)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: RS.xs, leading: RS.md,
                        bottom: RS.xs, trailing: RS.md
                    ))
            }
        }
    }

    /// Builds a single StoryNoteBubble row, determining own vs other styling.
    private func noteBubbleRow(for note: StoryNote) -> some View {
        let isOwn: Bool = note.userId == appState.currentUser?.id
        let name: String = isOwn ? noteDisplayName : note.authorName
        let initial: String = isOwn ? noteAvatarInitial : String(note.authorName.first ?? Character("?")).uppercased()
        let avatar: String? = isOwn ? appState.currentUser?.avatarUrl : viewModel.collaboratorAvatarUrl(forUserId: note.userId)

        return StoryNoteBubble(
            note: note,
            displayName: name,
            initial: initial,
            avatarUrl: avatar,
            isEditing: editingNoteId == note.id,
            isOwnMessage: isOwn,
            editText: editingNoteId == note.id ? $editingNoteText : .constant(""),
            onTap: {
                editingNoteId = note.id
                editingNoteText = note.text
            },
            onSave: {
                let trimmed = editingNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    Task { await viewModel.updateNote(id: note.id, storyId: story.id, newText: trimmed) }
                }
                editingNoteId = nil
            },
            onCancel: {
                editingNoteId = nil
            }
        )
    }

    private var notesHeader: some View {
        Text("Notes")
            .font(RF.tag)
            .textCase(.uppercase)
            .tracking(0.08 * 12)
            .foregroundStyle(Color.riffitTextTertiary)
            .padding(.top, RS.md)
            .padding(.bottom, RS.xs)
    }

    private var emptyNotesState: some View {
        VStack(spacing: RS.sm) {
            Text("No notes yet")
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextTertiary)

            Text("Add your first thought below.")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RS.lg)
    }

    // MARK: - People

    /// Display name for the current user in the People section: @username > fullName > @email_prefix, with "(You)" suffix.
    /// Used for any collaborator row where collaborator.userId == currentUser.id, regardless of role.
    private var currentUserDisplayName: String {
        let baseName: String = {
            if let username = appState.currentUser?.username?.trimmingCharacters(in: .whitespacesAndNewlines),
               !username.isEmpty {
                return "@\(username)"
            }
            if let fullName = appState.currentUser?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !fullName.isEmpty {
                return fullName
            }
            if let email = appState.currentUser?.email {
                let prefix = email.components(separatedBy: "@").first ?? ""
                if !prefix.isEmpty { return "@\(prefix)" }
            }
            return "You"
        }()
        return "\(baseName) (You)"
    }

    private var peopleHeader: some View {
        Text("Creators")
            .font(RF.tag)
            .textCase(.uppercase)
            .tracking(0.08 * 12)
            .foregroundStyle(Color.riffitTextTertiary)
            .padding(.top, RS.md)
            .padding(.bottom, RS.xs)
    }

    /// The "+ Invite" row at the bottom of the People section.
    /// Shows a lock icon if the owner has hit their collaborator limit.
    private var inviteRow: some View {
        let collaboratorLimit: Int = {
            switch appState.currentUser?.subscriptionTier {
            case .pro: return 2
            default: return 1
            }
        }()
        let activeCount = viewModel.collaborators(for: story.id)
            .filter { $0.role != .owner && $0.status == .accepted }
            .count
        let atLimit = activeCount >= collaboratorLimit

        return Button {
            if atLimit {
                // TODO: Show paywall
            } else {
                showInviteSheet = true
            }
        } label: {
            HStack(spacing: RS.sm) {
                Image(systemName: atLimit ? "lock.fill" : "plus.circle.fill")
                    .font(.body)
                    .foregroundStyle(atLimit ? Color.riffitTextTertiary : Color.riffitTeal400)

                Text(atLimit ? "Upgrade to add more" : "Invite")
                    .font(RF.label)
                    .foregroundStyle(atLimit ? Color.riffitTextTertiary : Color.riffitTeal400)

                Spacer()
            }
            .padding(RS.smPlus)
            .background(Color.riffitSurface)
            .cornerRadius(RR.input)
            .overlay(
                RoundedRectangle(cornerRadius: RR.input)
                    .stroke(
                        atLimit ? Color.riffitBorderSubtle : Color.riffitTeal400.opacity(0.3),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var noteInputRow: some View {
        HStack(alignment: .bottom, spacing: RS.smPlus) {
            TextField("Add a note...", text: $newNoteText, axis: .vertical)
                .lineLimit(1...5)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextPrimary)

            Button {
                let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                Task { await viewModel.addNote(to: story.id, text: trimmed, authorName: noteDisplayName, userId: appState.currentUser?.id) }
                newNoteText = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.riffitTextTertiary
                            : Color.riffitPrimary
                    )
            }
            .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(RS.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - Asset Row

/// Renders an asset with a type-specific filled icon and a smart title.
/// The system drag handle is provided by the List in edit mode —
/// no custom handle needed.
struct AssetRow: View {
    let asset: StoryAsset

    /// Tries to load a thumbnail for image/video assets from local files.
    private var mediaThumbnail: UIImage? {
        guard let path = asset.fileUrl else { return nil }

        switch asset.assetType {
        case .image:
            return ImageStorageService.load(from: path)
        case .video:
            return VideoStorageService.generateThumbnail(for: path)
                .flatMap { VideoStorageService.loadThumbnail(from: $0) }
        default:
            return nil
        }
    }

    var body: some View {
        HStack(spacing: RS.smPlus) {
            // Thumbnail for images/videos, icon for everything else
            if let thumb = mediaThumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: RR.tag))
            } else {
                Image(systemName: assetIconName)
                    .font(.caption)
                    .foregroundStyle(Color.riffitTeal600)
                    .frame(width: 32, height: 32)
                    .background(Color.riffitTealTint)
                    .cornerRadius(RR.tag)
            }

            // Content preview
            VStack(alignment: .leading, spacing: 2) {
                Text(assetTitle)
                    .font(RF.label)
                    .foregroundStyle(Color.riffitTextPrimary)

                Text(previewText)
                    .font(RF.meta)
                    .foregroundStyle(Color.riffitTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration for voice/video
            if let duration = asset.durationSeconds {
                Text(formatDuration(duration))
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextTertiary)
            }
        }
        .padding(RS.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    /// Filled SF Symbol name for each asset type.
    private var assetIconName: String {
        switch asset.assetType {
        case .voiceNote: return "waveform"
        case .video:     return "video.fill"
        case .image:     return "photo.fill"
        case .text:      return "doc.text.fill"
        }
    }

    /// Smart title: prefers asset.name if set, then detects
    /// "Hook:" / "Script:" prefixes, then first 3 words.
    private var assetTitle: String {
        // User-defined name takes priority for any asset type
        if let name = asset.name, !name.isEmpty {
            return name
        }

        switch asset.assetType {
        case .voiceNote: return "Voice Note"
        case .video:     return "Video"
        case .image:     return "Image"
        case .text:
            guard let text = asset.contentText,
                  !text.isEmpty
            else { return "Text" }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("Hook:") { return "Hook" }
            if trimmed.hasPrefix("Script:") { return "Script" }

            // First 3 words as a summary title
            let words = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            return words.prefix(3).joined(separator: " ")
        }
    }

    private var previewText: String {
        switch asset.assetType {
        case .voiceNote:
            return asset.fileUrl ?? "Recording"
        case .video:
            return "Video clip"
        case .image:
            return "Photo"
        case .text:
            return asset.contentText ?? "Empty text"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Section Header Row

/// A fixed row representing a named asset section.
/// Has a teal left accent bar, section name, and action buttons.
/// .moveDisabled(true) keeps it pinned while assets drag past.
struct SectionHeaderRow: View {
    let section: AssetSection
    var showActions: Bool = true
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: RS.sm) {
            // 3pt teal left accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.riffitTeal400)
                .frame(width: 3, height: 24)

            // Section name — .textCase(nil) prevents SwiftUI auto-uppercasing
            Text(section.name)
                .font(RF.label)
                .foregroundStyle(Color.riffitTeal400)
                .textCase(nil)

            Spacer()

            if showActions {
                // Rename
                Button {
                    onRename()
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
                .buttonStyle(.plain)
            }

            if showActions {
                // Delete section (assets fall back to unsectioned)
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, RS.xs)
    }
}

// MARK: - Story Note Bubble

/// A single note in the story thread with avatar + content layout.
/// Tap to enter inline edit mode — text becomes a TextEditor.
struct StoryNoteBubble: View {
    let note: StoryNote
    let displayName: String
    let initial: String
    let avatarUrl: String?
    let isEditing: Bool
    /// Whether this note was written by the current user — drives iMessage-style alignment
    let isOwnMessage: Bool
    @Binding var editText: String
    let onTap: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void

    /// iMessage-style corner radii: the "tail" corner is smaller
    private var bubbleCorners: RoundedCornerShape {
        if isOwnMessage {
            // Own messages: bottom-right is the tail
            RoundedCornerShape(tl: RR.input, tr: RR.input, bl: RR.input, br: RS.xs)
        } else {
            // Others' messages: bottom-left is the tail
            RoundedCornerShape(tl: RR.input, tr: RR.input, bl: RS.xs, br: RR.input)
        }
    }

    private var bubbleBackground: Color {
        if isEditing { return Color.riffitElevated }
        return isOwnMessage ? Color.riffitPrimaryTint : Color.riffitSurface
    }

    private var bubbleBorder: Color {
        if isEditing { return Color.riffitPrimary.opacity(0.5) }
        return isOwnMessage ? Color.riffitPrimary.opacity(0.15) : Color.riffitBorderSubtle
    }

    var body: some View {
        HStack {
            if isOwnMessage { Spacer(minLength: RS.xl3) }

            if isOwnMessage {
                ownBubble
            } else {
                otherBubble
            }

            if !isOwnMessage { Spacer(minLength: RS.xl3) }
        }
    }

    // MARK: - Own message (right-aligned, no avatar/name)

    private var ownBubble: some View {
        VStack(alignment: .trailing, spacing: RS.xs) {
            VStack(alignment: .trailing, spacing: RS.xs) {
                // Save/Cancel row when editing
                if isEditing {
                    editingControls
                }

                // Note text or inline editor
                noteContent
            }
            .padding(RS.smPlus)
            .background(bubbleBackground)
            .clipShape(bubbleCorners)
            .overlay(bubbleCorners.stroke(bubbleBorder, lineWidth: isEditing ? 1 : 0.5))
            .contentShape(Rectangle())
            .onTapGesture { if !isEditing { onTap() } }

            // Timestamp below the bubble
            if !isEditing {
                Text(note.createdAt.relativeTimestamp)
                    .font(RF.meta)
                    .foregroundStyle(Color.riffitTextTertiary)
            }
        }
    }

    // MARK: - Other person's message (left-aligned, avatar + name)

    private var otherBubble: some View {
        HStack(alignment: .top, spacing: RS.sm) {
            // Avatar — 28×28 circle
            if let urlString = avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    noteInitialsCircle
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            } else {
                noteInitialsCircle
            }

            VStack(alignment: .leading, spacing: RS.xs) {
                // Author name + timestamp above the bubble
                HStack(spacing: 0) {
                    Text(displayName)
                        .font(RF.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.riffitTextPrimary)

                    if !isEditing {
                        Text(" · \(note.createdAt.relativeTimestamp)")
                            .font(RF.meta)
                            .foregroundStyle(Color.riffitTextTertiary)
                    }

                    Spacer()

                    if isEditing {
                        editingControls
                    }
                }

                // Bubble
                VStack(alignment: .leading, spacing: RS.xs) {
                    noteContent
                }
                .padding(RS.smPlus)
                .background(bubbleBackground)
                .clipShape(bubbleCorners)
                .overlay(bubbleCorners.stroke(bubbleBorder, lineWidth: isEditing ? 1 : 0.5))
                .contentShape(Rectangle())
                .onTapGesture { if !isEditing { onTap() } }
            }
        }
    }

    // MARK: - Shared subviews

    private var editingControls: some View {
        HStack(spacing: RS.sm) {
            Button { onCancel() } label: {
                Text("Cancel")
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextTertiary)
            }
            Button { onSave() } label: {
                Text("Save")
                    .font(RF.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.riffitPrimary)
            }
        }
    }

    @ViewBuilder
    private var noteContent: some View {
        if isEditing {
            TextEditor(text: $editText)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 40)
        } else {
            Text(note.text)
                .font(RF.bodyMd)
                .foregroundStyle(isOwnMessage ? Color.riffitTextPrimary : Color.riffitTextSecondary)
        }
    }

    /// Initials circle fallback for when no avatar URL is available
    private var noteInitialsCircle: some View {
        Text(initial)
            .font(RF.caption)
            .foregroundStyle(Color.riffitTextPrimary)
            .frame(width: 28, height: 28)
            .background(Color.riffitTeal600)
            .clipShape(Circle())
    }
}

/// Shape with independently controllable corner radii for iMessage-style bubbles.
struct RoundedCornerShape: Shape {
    let tl: CGFloat
    let tr: CGFloat
    let bl: CGFloat
    let br: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: tl, y: 0))
        path.addLine(to: CGPoint(x: w - tr, y: 0))
        path.addArc(tangent1End: CGPoint(x: w, y: 0), tangent2End: CGPoint(x: w, y: tr), radius: tr)
        path.addLine(to: CGPoint(x: w, y: h - br))
        path.addArc(tangent1End: CGPoint(x: w, y: h), tangent2End: CGPoint(x: w - br, y: h), radius: br)
        path.addLine(to: CGPoint(x: bl, y: h))
        path.addArc(tangent1End: CGPoint(x: 0, y: h), tangent2End: CGPoint(x: 0, y: h - bl), radius: bl)
        path.addLine(to: CGPoint(x: 0, y: tl))
        path.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: tl, y: 0), radius: tl)
        path.closeSubpath()

        return path
    }
}

// MARK: - Edit Text Asset View

/// Full-screen editor for text assets. Opens when tapping a text asset row.
/// Name field at top, text editor below, auto-focuses keyboard.
struct EditTextAssetView: View {
    let asset: StoryAsset
    @ObservedObject var viewModel: StorybankViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var assetName: String = ""
    @State private var text: String = ""

    private enum Field { case name, editor }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Name field
                TextField("Name (optional)", text: $assetName)
                    .font(RF.label)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .padding(RS.smPlus)
                    .background(Color.riffitElevated)
                    .cornerRadius(RR.button)
                    .padding(.horizontal, RS.md)
                    .padding(.top, RS.sm)
                    .focused($focusedField, equals: .name)

                Divider()
                    .padding(.horizontal, RS.md)
                    .padding(.vertical, RS.sm)

                // Text editor with character count
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: $text)
                        .font(RF.bodyMd)
                        .foregroundStyle(Color.riffitTextPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, RS.md)
                        .padding(.bottom, RS.xl2)
                        .focused($focusedField, equals: .editor)

                    // Character count
                    Text("\(text.count)")
                        .font(RF.meta)
                        .foregroundStyle(Color.riffitTextTertiary)
                        .padding(.trailing, RS.md)
                        .padding(.bottom, RS.smPlus)
                }
            }
            .background(Color.riffitBackground)
            .navigationTitle("Edit note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let trimmedName = assetName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            await viewModel.updateAsset(
                                asset,
                                name: trimmedName.isEmpty ? nil : trimmedName,
                                text: trimmedText
                            )
                        }
                        dismiss()
                    }
                    .font(RF.button)
                    .foregroundStyle(Color.riffitPrimary)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.riffitTextSecondary)
                }
            }
        }
        .onAppear {
            assetName = asset.name ?? ""
            text = asset.contentText ?? ""
            // Small delay so the view is fully laid out before focusing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .editor
            }
        }
    }
}

// MARK: - Reference Card

/// Shows a reference to an inspiration video with tag and title.
struct ReferenceCard: View {
    let reference: StoryReference
    @ObservedObject var viewModel: StorybankViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel

    /// Looks up the linked video to display its title.
    private var linkedVideo: InspirationVideo? {
        libraryViewModel.videos.first { $0.id == reference.inspirationVideoId }
    }

    /// Title hierarchy: video.title → first 8 words of userNote → platform + "reel"
    private var referenceTitle: String {
        guard let video = linkedVideo else { return "Linked inspiration" }

        if let title = video.title, !title.isEmpty {
            return title
        }

        if let note = video.userNote, !note.isEmpty {
            let words = note.split(separator: " ", omittingEmptySubsequences: true)
            if words.count <= 8 {
                return note
            }
            return words.prefix(8).joined(separator: " ") + "..."
        }

        return video.platform.displayLabel + " reel"
    }

    /// Platform dot color matching InspirationCard and InfluencesView
    private var platformDotColor: Color {
        guard let video = linkedVideo else { return Color.riffitTextTertiary }
        switch video.platform {
        case .youtube:   return Color(red: 232/255, green: 69/255, blue: 60/255)
        case .tiktok:    return Color(red: 105/255, green: 201/255, blue: 208/255)
        case .instagram: return Color(red: 193/255, green: 53/255, blue: 132/255)
        case .linkedin:  return Color(red: 0/255, green: 119/255, blue: 181/255)
        case .x:         return Color.riffitTextTertiary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            // Section tag + idea tags on one line
            let videoTags = libraryViewModel.tags(for: reference.inspirationVideoId)
            let hasSection = !reference.referenceTag.isEmpty
            if hasSection || !videoTags.isEmpty {
                HStack(spacing: 6) {
                    // Section tag first (teal)
                    if hasSection {
                        HStack(spacing: RS.xs) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.riffitTeal400)
                                .frame(width: 3, height: 12)

                            Text(reference.referenceTag)
                                .font(RF.tag)
                                .foregroundStyle(Color.riffitTeal400)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(Color.riffitTealTint)
                        .clipShape(Capsule())
                    }

                    // Idea tags (gold)
                    ForEach(videoTags, id: \.self) { tag in
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

            // Video title from the Library
            Text(referenceTitle)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextPrimary)
                .lineLimit(2)

            // Platform indicator + tag pill
            if let video = linkedVideo {
                HStack {
                    // Platform dot + name
                    HStack(spacing: 6) {
                        Circle()
                            .fill(platformDotColor)
                            .frame(width: 6, height: 6)

                        Text(video.platform.displayLabel)
                            .font(RF.tag)
                            .textCase(.uppercase)
                            .tracking(0.06 * 11)
                            .foregroundStyle(Color.riffitTextTertiary)
                    }

                    Spacer()
                }
            }

            // "Your take" — user note from the original idea
            if let video = linkedVideo,
               let note = video.userNote,
               !note.isEmpty {
                HStack(spacing: 4) {
                    Text("Your take:")
                        .font(RF.caption)
                        .foregroundStyle(Color.riffitTextTertiary)
                    Text(note)
                        .font(RF.caption)
                        .foregroundStyle(Color.riffitTextSecondary)
                        .italic()
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
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
}

// MARK: - Add Text Asset Sheet

/// Simple bottom sheet for adding a text asset to a story.
struct AddTextAssetSheet: View {
    let storyId: UUID
    @ObservedObject var viewModel: StorybankViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""

    var body: some View {
        VStack(spacing: RS.lg) {
            // Drag handle
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, RS.smPlus)

            Text("Add Text")
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)

            TextField("Write your thoughts...", text: $text, axis: .vertical)
                .lineLimit(3...8)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextPrimary)
                .padding(RS.smPlus)
                .background(Color.riffitSurface)
                .cornerRadius(RR.input)
                .overlay(
                    RoundedRectangle(cornerRadius: RR.input)
                        .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                )

            Spacer()

            RiffitButton(title: "Add", variant: .primary) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    Task { await viewModel.addTextAsset(to: storyId, text: trimmed) }
                }
                dismiss()
            }
        }
        .padding(.horizontal, RS.md)
        .padding(.bottom, RS.lg)
        .background(Color.riffitBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(RR.modal)
    }
}
