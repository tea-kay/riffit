import SwiftUI

/// The core capture sheet — a bottom sheet for saving an IG link
/// with an optional note and tags. Designed to be completable
/// in under 10 seconds. Nothing is required except the URL.
struct AddInspirationView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var urlText: String = ""
    @State private var userNote: String = ""
    @State private var selectedTags: Set<String> = []
    @State private var selectedFolderId: UUID?
    @State private var showURLError: Bool = false

    var body: some View {
        VStack(spacing: RS.lg) {
            // Drag handle
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, RS.smPlus)

            // URL preview
            urlPreview

            // Note field
            TextField("What caught your eye?", text: $userNote, axis: .vertical)
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden) // We draw our own handle
        .presentationCornerRadius(RR.modal)
    }

    // MARK: - URL Preview

    private var urlPreview: some View {
        VStack(spacing: RS.sm) {
            HStack(spacing: RS.smPlus) {
                // IG icon
                Image(systemName: "camera")
                    .font(.callout)
                    .foregroundStyle(Color.riffitTeal400)
                    .frame(width: 32, height: 32)
                    .background(Color.riffitTealTint)
                    .cornerRadius(RR.tag)

                if urlText.isEmpty {
                    // Empty state — prompt to paste
                    TextField("Paste an Instagram link...", text: $urlText)
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
                Text("Paste a valid Instagram link.")
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
                ForEach(IdeaTag.defaults, id: \.self) { tag in
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
                }
            }
        }
    }

    // MARK: - Folder Picker

    private var folderPicker: some View {
        HStack(spacing: RS.smPlus) {
            Image(systemName: "folder")
                .font(.callout)
                .foregroundStyle(Color.riffitPrimary)
                .frame(width: 32, height: 32)
                .background(Color.riffitPrimaryTint)
                .cornerRadius(RR.tag)

            Menu {
                Button {
                    selectedFolderId = nil
                } label: {
                    Label("No folder", systemImage: selectedFolderId == nil ? "checkmark" : "")
                }

                ForEach(viewModel.folders) { folder in
                    Button {
                        selectedFolderId = folder.id
                    } label: {
                        Label(folder.name, systemImage: selectedFolderId == folder.id ? "checkmark" : "")
                    }
                }
            } label: {
                HStack {
                    Text(selectedFolderName)
                        .font(RF.bodyMd)
                        .foregroundStyle(Color.riffitTextPrimary)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
            }
        }
        .padding(RS.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
        )
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
        guard let url = URL(string: urlText) else { return urlText }
        let path = url.path
        if path.count > 1 {
            return "instagram.com" + path
        }
        return url.host ?? urlText
    }

    // MARK: - Save

    private func save() {
        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isInstagramURL(trimmedURL) else {
            showURLError = true
            return
        }

        let trimmedNote = userNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = Array(selectedTags)

        Task {
            await viewModel.addVideo(
                url: trimmedURL,
                platform: .instagram,
                userNote: trimmedNote.isEmpty ? nil : trimmedNote,
                tags: tags.isEmpty ? nil : tags,
                folderId: selectedFolderId
            )
        }

        dismiss()
    }

    private func isInstagramURL(_ urlString: String) -> Bool {
        let lowered = urlString.lowercased()
        return lowered.contains("instagram.com") || lowered.contains("instagr.am")
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
