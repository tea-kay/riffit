import SwiftUI

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
    @State private var playingVoiceAsset: StoryAsset?
    @State private var viewingImageAsset: StoryAsset?
    @State private var showAddReferenceSheet: Bool = false
    @State private var showAddSectionModal: Bool = false
    @State private var newSectionName: String = ""
    @State private var editingAsset: StoryAsset?
    @State private var selectedVideo: InspirationVideo?
    @State private var showRenameModal: Bool = false
    @State private var renameText: String = ""
    @State private var renamingSection: AssetSection?
    @State private var renameSectionText: String = ""
    @EnvironmentObject var libraryViewModel: LibraryViewModel

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
                                onRename: {
                                    renameSectionText = section.name
                                    renamingSection = section
                                },
                                onDelete: {
                                    viewModel.deleteSection(section)
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
                                    default:
                                        break
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.deleteAsset(asset)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
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
                        // Reorder the flat array, then reassign sectionIDs
                        // based on which section header each asset falls under
                        var reordered = viewModel.flatRows(for: story.id)
                        reordered.move(fromOffsets: from, toOffset: to)
                        viewModel.applyFlatRowOrder(for: story.id, reordered: reordered)
                    }
                    .deleteDisabled(true)
                }
            } header: {
                assetsHeader
            }

            // MARK: References Section
            Section {
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
                                Button(role: .destructive) {
                                    viewModel.deleteReference(reference)
                                } label: {
                                    Label("Remove", systemImage: "trash")
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
                        viewModel.moveReference(in: story.id, from: from, to: to)
                    }
                    .deleteDisabled(true)
                }
            } header: {
                referencesHeader
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
                    Button {
                        renameText = currentStory.title
                        showRenameModal = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Button {
                        viewModel.updateStoryStatus(story, to: .archived)
                        dismiss()
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }

                    Button {
                        // TODO: Share flow
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive) {
                        viewModel.deleteStory(story)
                        dismiss()
                    } label: {
                        Label("Delete Story", systemImage: "trash")
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
                    viewModel.updateStoryTitle(story, to: name)
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
                    viewModel.addSection(to: story.id, name: name)
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
                        viewModel.renameSection(section, to: name)
                    }
                    renamingSection = nil
                }
            )
        }
    }

    // MARK: - Section Headers

    private var assetsHeader: some View {
        HStack {
            Text("My Assets")
                .font(RF.tag)
                .textCase(.uppercase)
                .tracking(0.08 * 12)
                .foregroundStyle(Color.riffitTextTertiary)

            Spacer()

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
                    // TODO: Video picker flow
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
}

// MARK: - Asset Row

/// Renders an asset with a type-specific filled icon and a smart title.
/// The system drag handle is provided by the List in edit mode —
/// no custom handle needed.
struct AssetRow: View {
    let asset: StoryAsset

    var body: some View {
        HStack(spacing: RS.smPlus) {
            // Type-specific filled icon
            Image(systemName: assetIconName)
                .font(.caption)
                .foregroundStyle(Color.riffitTeal600)
                .frame(width: 32, height: 32)
                .background(Color.riffitTealTint)
                .cornerRadius(RR.tag)

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
            return asset.fileUrl ?? "Video clip"
        case .image:
            return asset.fileUrl ?? "Photo"
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

            // Rename
            Button {
                onRename()
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(Color.riffitTextTertiary)
            }
            .buttonStyle(.plain)

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
        .padding(.vertical, RS.xs)
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
                        viewModel.updateAsset(
                            asset,
                            name: trimmedName.isEmpty ? nil : trimmedName,
                            text: trimmedText
                        )
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

            // AI relevance note (generated when AI features are enabled)
            if let note = reference.aiRelevanceNote {
                Text(note)
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextSecondary)
                    .italic()
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
                    viewModel.addTextAsset(to: storyId, text: trimmed)
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
