import SwiftUI

/// The core capture sheet — a bottom sheet for saving an IG link
/// with an optional note, tags, and stats. Designed to be completable
/// in under 10 seconds. Nothing is required except the URL.
struct AddInspirationView: View {
    @ObservedObject var viewModel: LibraryViewModel
    var preselectedFolderId: UUID? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var urlText: String = ""
    @State private var titleText: String = ""
    @State private var userNote: String = ""
    @State private var selectedTags: Set<String> = []
    @State private var selectedFolderId: UUID?
    @State private var showURLError: Bool = false
    @State private var showNewTagField: Bool = false
    @State private var newTagText: String = ""

    /// Auto-detected platform from the pasted URL
    private var detectedPlatform: InspirationVideo.Platform? {
        PlatformDetector.detect(from: urlText)
    }

    var body: some View {
        VStack(spacing: RS.lg) {
            // Drag handle
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, RS.smPlus)

            // URL preview
            urlPreview

            // Title field — optional, manual entry
            TextField("Add a title...", text: $titleText)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextPrimary)
                .padding(RS.smPlus)
                .background(Color.riffitElevated)
                .cornerRadius(RR.button)

            // Note field
            TextField("Your take", text: $userNote, axis: .vertical)
                .lineLimit(2...4)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextPrimary)
                .padding(RS.smPlus)
                .background(Color.riffitSurface)
                .cornerRadius(RR.input)
                .overlay(
                    RoundedRectangle(cornerRadius: RR.input)
                        .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                )

            // Tag selector
            tagSelector

            // Folder picker — only shown when folders exist
            if !viewModel.folders.isEmpty {
                folderPicker
            }

            Spacer()

            // Save button
            RiffitButton(title: "Save", variant: .primary) {
                save()
            }
        }
        .padding(.horizontal, RS.md)
        .padding(.bottom, RS.lg)
        .background(Color.riffitBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(RR.modal)
        .onAppear {
            if selectedFolderId == nil, let folderId = preselectedFolderId {
                selectedFolderId = folderId
            }
        }
    }

    // MARK: - URL Preview

    private var urlPreview: some View {
        VStack(spacing: RS.sm) {
            HStack(spacing: RS.smPlus) {
                // Platform icon — changes based on detected URL
                Image(systemName: PlatformDetector.icon(for: detectedPlatform ?? .instagram))
                    .font(.callout)
                    .foregroundStyle(Color.riffitTeal400)
                    .frame(width: 32, height: 32)
                    .background(Color.riffitTealTint)
                    .cornerRadius(RR.tag)

                if urlText.isEmpty {
                    // Empty state — prompt to paste
                    TextField(PlatformDetector.urlPlaceholder(for: nil), text: $urlText)
                        .font(RF.bodyMd)
                        .foregroundStyle(Color.riffitTextPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                } else {
                    // Show the pasted URL, tappable to edit
                    Text(displayURL)
                        .font(RF.bodyMd)
                        .foregroundStyle(Color.riffitTextPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Clear button
                    Button {
                        urlText = ""
                        showURLError = false
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
            .overlay(
                RoundedRectangle(cornerRadius: RR.input)
                    .stroke(showURLError ? Color.riffitDanger : Color.riffitBorderDefault, lineWidth: 0.5)
            )

            if showURLError {
                Text("Paste a valid video link (Instagram or YouTube).")
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Tag Selector

    private var tagSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RS.sm) {
                ForEach(viewModel.allTags, id: \.self) { tag in
                    TagPill(
                        label: tag,
                        isSelected: selectedTags.contains(tag)
                    ) {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                    // Long-press to delete any tag from the available list
                    .contextMenu {
                        Button(role: .destructive) {
                            selectedTags.remove(tag)
                            viewModel.removeAvailableTag(tag)
                        } label: {
                            Label("Delete Tag", systemImage: "trash")
                        }
                    }
                }

                // Inline new tag creation
                if showNewTagField {
                    HStack(spacing: RS.xs) {
                        TextField("Tag name", text: $newTagText)
                            .font(RF.caption)
                            .foregroundStyle(Color.riffitTextPrimary)
                            .frame(width: 80)
                            .onSubmit { submitCaptureTag() }

                        Button {
                            submitCaptureTag()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.callout)
                                .foregroundStyle(Color.riffitPrimary)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, RS.smPlus)
                    .background(Color.riffitSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                    )
                } else {
                    Button {
                        showNewTagField = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundStyle(Color.riffitTextTertiary)
                            .frame(width: 32, height: 32)
                            .background(Color.riffitSurface)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func submitCaptureTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            viewModel.addCustomTag(trimmed)
            selectedTags.insert(trimmed)
        }
        newTagText = ""
        showNewTagField = false
    }

    // MARK: - Folder Picker

    private var folderPicker: some View {
        Menu {
            Button {
                selectedFolderId = nil
            } label: {
                Label("No folder", systemImage: selectedFolderId == nil ? "checkmark" : "folder")
            }

            ForEach(viewModel.folders) { folder in
                Button {
                    selectedFolderId = folder.id
                } label: {
                    Label(folder.name, systemImage: selectedFolderId == folder.id ? "checkmark" : "folder")
                }
            }
        } label: {
            HStack(spacing: RS.smPlus) {
                Image(systemName: "folder")
                    .font(.callout)
                    .foregroundStyle(Color.riffitPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.riffitPrimaryTint)
                    .cornerRadius(RR.tag)

                Text(selectedFolderName)
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextPrimary)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(Color.riffitTextTertiary)
            }
            .contentShape(Rectangle())
            .padding(RS.smPlus)
            .background(Color.riffitSurface)
            .cornerRadius(RR.input)
            .overlay(
                RoundedRectangle(cornerRadius: RR.input)
                    .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
            )
        }
    }

    private var selectedFolderName: String {
        if let folderId = selectedFolderId,
           let folder = viewModel.folders.first(where: { $0.id == folderId }) {
            return folder.name
        }
        return "No folder"
    }

    // MARK: - Display URL

    /// Shows a shortened version of the URL for the preview pill.
    private var displayURL: String {
        guard let url = URL(string: urlText),
              let host = url.host else { return urlText }
        let cleanHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let path = url.path
        if path.count > 1 {
            let truncated = path.count > 30 ? String(path.prefix(30)) + "..." : path
            return cleanHost + truncated
        }
        return cleanHost
    }

    // MARK: - Save

    private func save() {
        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let platform = PlatformDetector.detect(from: trimmedURL) else {
            showURLError = true
            return
        }

        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = userNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = Array(selectedTags)

        Task {
            await viewModel.addVideo(
                url: trimmedURL,
                platform: platform,
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                userNote: trimmedNote.isEmpty ? nil : trimmedNote,
                tags: tags.isEmpty ? nil : tags,
                folderId: selectedFolderId
            )
        }

        dismiss()
    }
}

// MARK: - Tag Pill

/// A selectable pill for tagging an idea.
struct TagPill: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(RF.button)
                .foregroundStyle(isSelected ? Color.riffitOnPrimary : Color.riffitTextSecondary)
                .padding(.vertical, 8)
                .padding(.horizontal, RS.md)
                .background(isSelected ? Color.riffitPrimary : Color.riffitSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.riffitBorderDefault, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Default Tags

enum IdeaTag {
    static let defaults: [String] = [
        "Hook",
        "Editing",
        "B-Roll",
        "Format",
        "Topic",
        "Inspiration",
    ]
}
