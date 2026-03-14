import SwiftUI

/// Shows the ideas inside a folder. Supports renaming, deleting
/// the folder, and removing ideas from it.
struct FolderDetailView: View {
    let folder: IdeaFolder
    @ObservedObject var viewModel: LibraryViewModel

    @State private var showRenameAlert: Bool = false
    @State private var renameText: String = ""
    @State private var showDeleteConfirm: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            let folderVideos = viewModel.videos(in: folder)

            if folderVideos.isEmpty {
                emptyFolder
            } else {
                ScrollView {
                    LazyVStack(spacing: .smPlus) {
                        ForEach(folderVideos) { video in
                            NavigationLink(value: video) {
                                IdeaRow(video: video, tags: viewModel.tags(for: video.id))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    viewModel.moveVideo(video.id, to: nil)
                                } label: {
                                    Label("Remove from Folder", systemImage: "folder.badge.minus")
                                }
                            }
                            .draggable(video.id.uuidString)
                        }
                    }
                    .padding(.horizontal, .md)
                    .padding(.vertical, .smPlus)
                }
                .navigationDestination(for: InspirationVideo.self) { video in
                    InspirationDetailView(video: video, viewModel: viewModel)
                }
            }
        }
        .navigationTitle(folder.name)
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
        .alert("Rename Folder", isPresented: $showRenameAlert) {
            TextField("Folder name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    viewModel.renameFolder(folder, to: trimmed)
                }
            }
        }
        .alert("Delete Folder?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteFolder(folder)
                dismiss()
            }
        } message: {
            Text("Ideas inside will be moved back to Unfiled.")
        }
    }

    private var emptyFolder: some View {
        VStack(spacing: .md) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(Color.riffitTextTertiary)

            Text("This folder is empty")
                .riffitBody()
                .foregroundStyle(Color.riffitTextSecondary)

            Text("Drag ideas here from the main list.")
                .riffitCaption()
                .foregroundStyle(Color.riffitTextTertiary)
        }
    }
}
