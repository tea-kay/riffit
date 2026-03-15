import SwiftUI

/// Manages the ideas list, folders, and tags.
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var videos: [InspirationVideo] = []
    @Published var folders: [IdeaFolder] = []
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var error: Error?

    /// Maps video ID → folder ID. Videos not in this dictionary are unfiled.
    @Published var videoFolderMap: [UUID: UUID] = [:]

    /// Maps video ID → tags. Tracked here until we add a tags column to Supabase.
    @Published var videoTagsMap: [UUID: [String]] = [:]

    /// Maps video ID → comments. Each video has a thread of comments.
    @Published var videoCommentsMap: [UUID: [IdeaComment]] = [:]

    var isEmpty: Bool { videos.isEmpty && folders.isEmpty }

    var unfiledVideos: [InspirationVideo] {
        videos.filter { videoFolderMap[$0.id] == nil }
    }

    func videos(in folder: IdeaFolder) -> [InspirationVideo] {
        videos.filter { videoFolderMap[$0.id] == folder.id }
    }

    func tags(for videoId: UUID) -> [String] {
        videoTagsMap[videoId] ?? []
    }

    /// Returns comments for a video, sorted oldest first (chat order).
    func comments(for videoId: UUID) -> [IdeaComment] {
        (videoCommentsMap[videoId] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    /// Adds a new comment to a video's thread.
    func addComment(to videoId: UUID, text: String) {
        let comment = IdeaComment(inspirationVideoId: videoId, text: text)
        videoCommentsMap[videoId, default: []].append(comment)
    }

    // MARK: - Fetch

    func fetchVideos() async {
        isLoading = true
        error = nil

        // TODO: Fetch from Supabase

        isLoading = false
    }

    // MARK: - Add Video

    func addVideo(url: String, platform: InspirationVideo.Platform, userNote: String?, tags: [String]?, folderId: UUID? = nil) async {
        isSubmitting = true

        // TODO: Save to Supabase + call analyze-video edge function

        let newVideo = InspirationVideo(
            id: UUID(),
            creatorProfileId: UUID(),
            url: url,
            platform: platform,
            userNote: userNote,
            thumbnailUrl: nil,
            transcript: nil,
            alignmentScore: nil,
            alignmentVerdict: nil,
            alignmentReasoning: nil,
            status: .pending,
            savedAt: Date()
        )

        if let tags, !tags.isEmpty {
            videoTagsMap[newVideo.id] = tags
        }

        // File into folder if one was selected
        if let folderId {
            videoFolderMap[newVideo.id] = folderId
        }

        // Seed the first comment from the user note
        if let userNote, !userNote.isEmpty {
            let firstComment = IdeaComment(inspirationVideoId: newVideo.id, text: userNote)
            videoCommentsMap[newVideo.id] = [firstComment]
        }

        videos.insert(newVideo, at: 0)
        isSubmitting = false
    }

    // MARK: - Folders

    func createFolder(name: String) {
        let folder = IdeaFolder(name: name)
        folders.append(folder)
    }

    func renameFolder(_ folder: IdeaFolder, to name: String) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].name = name
    }

    func deleteFolder(_ folder: IdeaFolder) {
        for (videoId, folderId) in videoFolderMap where folderId == folder.id {
            videoFolderMap.removeValue(forKey: videoId)
        }
        folders.removeAll { $0.id == folder.id }
    }

    func moveVideo(_ videoId: UUID, to folderId: UUID?) {
        if let folderId {
            videoFolderMap[videoId] = folderId
        } else {
            videoFolderMap.removeValue(forKey: videoId)
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await fetchVideos()
    }
}
