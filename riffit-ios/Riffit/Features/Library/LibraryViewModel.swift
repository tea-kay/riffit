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

    /// Returns non-archived videos for use in pickers.
    var activeVideos: [InspirationVideo] {
        videos.filter { $0.status != .archived }
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

    func addVideo(
        url: String,
        platform: InspirationVideo.Platform,
        title: String?,
        userNote: String?,
        tags: [String]?,
        folderId: UUID? = nil
    ) async {
        isSubmitting = true

        // TODO: Save to Supabase

        let newVideo = InspirationVideo(
            id: UUID(),
            creatorProfileId: UUID(),
            url: url,
            platform: platform,
            title: title,
            userNote: userNote,
            thumbnailUrl: nil,
            transcript: nil,
            alignmentScore: nil,
            alignmentVerdict: nil,
            alignmentReasoning: nil,
            status: .saved,
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

    // MARK: - Update Title

    func updateTitle(for videoId: UUID, title: String) {
        guard let index = videos.firstIndex(where: { $0.id == videoId }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        videos[index].title = trimmed.isEmpty ? nil : trimmed
        // TODO: Update title in Supabase inspiration_videos table
    }

    // MARK: - Fetch Video Metadata

    /// Calls fetch-video-metadata Edge Function in the background to get
    /// title, thumbnail, and stats for a URL. Returns the metadata if
    /// successful, nil if the fetch fails.
    func fetchVideoMetadata(url: String) async -> EdgeFunctions.FetchVideoMetadataResponse? {
        do {
            return try await EdgeFunctions.shared.fetchVideoMetadata(url: url)
        } catch {
            // Metadata fetch is best-effort — if it fails, the user can enter manually
            return nil
        }
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
