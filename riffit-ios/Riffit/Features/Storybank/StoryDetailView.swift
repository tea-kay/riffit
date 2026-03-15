import SwiftUI

/// Detail view for a single Story. Two sections:
/// 1. My Assets — voice notes, video, images, text (reorderable)
/// 2. References — links to inspiration videos from the Library
struct StoryDetailView: View {
    let story: Story
    @ObservedObject var viewModel: StorybankViewModel

    @State private var showAddAssetMenu: Bool = false
    @State private var showAddTextSheet: Bool = false
    @State private var showAddReferenceSheet: Bool = false
    @State private var showStatusPicker: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .xl) {
                assetsSection
                referencesSection
            }
            .padding(.md)
        }
        .background(Color.riffitBackground)
        .navigationTitle(story.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    // Status picker
                    Menu {
                        ForEach(Story.Status.allCases, id: \.self) { status in
                            Button {
                                viewModel.updateStoryStatus(story, to: status)
                            } label: {
                                if story.status == status {
                                    Label(status.label, systemImage: "checkmark")
                                } else {
                                    Text(status.label)
                                }
                            }
                        }
                    } label: {
                        Label("Status", systemImage: "circle.dashed")
                    }

                    Divider()

                    Button(role: .destructive) {
                        viewModel.deleteStory(story)
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
    }

    // MARK: - Assets Section

    private var assetsSection: some View {
        VStack(alignment: .leading, spacing: .smPlus) {
            HStack {
                Text("My Assets")
                    .riffitLabel()
                    .foregroundStyle(Color.riffitTextTertiary)

                Spacer()

                Menu {
                    Button {
                        // TODO: Voice recording flow
                    } label: {
                        Label("Voice Note", systemImage: "waveform")
                    }

                    Button {
                        // TODO: Video picker flow
                    } label: {
                        Label("Video", systemImage: "video")
                    }

                    Button {
                        // TODO: Image picker flow
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

            let assets = viewModel.assets(for: story.id)

            if assets.isEmpty {
                emptyAssetsState
            } else {
                ForEach(assets) { asset in
                    AssetRow(asset: asset)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteAsset(asset)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var emptyAssetsState: some View {
        VStack(spacing: .sm) {
            Text("No assets yet")
                .riffitBody()
                .foregroundStyle(Color.riffitTextTertiary)

            Text("Add voice notes, video, images, or text.")
                .riffitCaption()
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .lg)
    }

    // MARK: - References Section

    private var referencesSection: some View {
        VStack(alignment: .leading, spacing: .smPlus) {
            HStack {
                Text("References")
                    .riffitLabel()
                    .foregroundStyle(Color.riffitTextTertiary)

                Spacer()

                Button {
                    showAddReferenceSheet = true
                } label: {
                    HStack(spacing: .xs) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add from Library")
                            .riffitCaption()
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.riffitPrimary)
                }
            }

            let references = viewModel.references(for: story.id)

            if references.isEmpty {
                emptyReferencesState
            } else {
                ForEach(references) { reference in
                    ReferenceCard(reference: reference, viewModel: viewModel)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteReference(reference)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var emptyReferencesState: some View {
        VStack(spacing: .sm) {
            Text("No references yet")
                .riffitBody()
                .foregroundStyle(Color.riffitTextTertiary)

            Text("Pull ideas from your Library.")
                .riffitCaption()
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .lg)
    }
}

// MARK: - Asset Row

/// Renders an asset with a type-specific icon and preview.
struct AssetRow: View {
    let asset: StoryAsset

    var body: some View {
        HStack(spacing: .smPlus) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(Color.riffitTextTertiary)

            // Type-specific icon
            assetIcon
                .frame(width: 32, height: 32)
                .background(Color.riffitTealTint)
                .cornerRadius(.tagRadius)

            // Content preview
            VStack(alignment: .leading, spacing: 2) {
                Text(assetTypeLabel)
                    .riffitCaption()
                    .fontWeight(.medium)
                    .foregroundStyle(Color.riffitTextPrimary)

                Text(previewText)
                    .riffitCaption()
                    .foregroundStyle(Color.riffitTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration for voice/video
            if let duration = asset.durationSeconds {
                Text(formatDuration(duration))
                    .riffitCaption()
                    .foregroundStyle(Color.riffitTextTertiary)
            }
        }
        .padding(.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(.inputRadius)
        .overlay(
            RoundedRectangle(cornerRadius: .inputRadius)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    private var assetIcon: some View {
        Group {
            switch asset.assetType {
            case .voiceNote:
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(Color.riffitTeal400)
            case .video:
                Image(systemName: "video")
                    .font(.caption)
                    .foregroundStyle(Color.riffitTeal400)
            case .image:
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundStyle(Color.riffitTeal400)
            case .text:
                Image(systemName: "text.alignleft")
                    .font(.caption)
                    .foregroundStyle(Color.riffitTeal400)
            }
        }
    }

    private var assetTypeLabel: String {
        switch asset.assetType {
        case .voiceNote: return "Voice Note"
        case .video: return "Video"
        case .image: return "Image"
        case .text: return "Text"
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

// MARK: - Reference Card

/// Shows a reference to an inspiration video with tag and AI note.
struct ReferenceCard: View {
    let reference: StoryReference
    @ObservedObject var viewModel: StorybankViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: .sm) {
            // Tag pill
            Text(reference.referenceTag)
                .font(.riffitTag)
                .foregroundStyle(Color.riffitPrimary)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.riffitPrimaryTint)
                .clipShape(Capsule())

            // Original note from the library video (if available)
            // Look up the video's userNote through the shared library
            Text("Linked inspiration")
                .riffitBody()
                .foregroundStyle(Color.riffitTextPrimary)
                .lineLimit(2)

            // AI relevance note
            if let note = reference.aiRelevanceNote {
                Text(note)
                    .riffitCaption()
                    .foregroundStyle(Color.riffitTextSecondary)
                    .italic()
            } else {
                Text("AI relevance note pending...")
                    .riffitCaption()
                    .foregroundStyle(Color.riffitTextTertiary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(.inputRadius)
        .overlay(
            RoundedRectangle(cornerRadius: .inputRadius)
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
        VStack(spacing: .lg) {
            // Drag handle
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, .smPlus)

            Text("Add Text")
                .riffitHeading()
                .foregroundStyle(Color.riffitTextPrimary)

            TextField("Write your thoughts...", text: $text, axis: .vertical)
                .lineLimit(3...8)
                .riffitBody()
                .foregroundStyle(Color.riffitTextPrimary)
                .padding(.smPlus)
                .background(Color.riffitSurface)
                .cornerRadius(.inputRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: .inputRadius)
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
        .padding(.horizontal, .md)
        .padding(.bottom, .lg)
        .background(Color.riffitBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(.sheetRadius)
    }
}
