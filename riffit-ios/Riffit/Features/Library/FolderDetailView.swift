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
                message: "Ideas inside will be moved back to Unfiled.",
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
