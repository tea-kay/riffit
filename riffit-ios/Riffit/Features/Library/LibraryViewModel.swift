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

    /// The full list of available tags. Starts with defaults, but the user
    /// can add new ones or remove any (including defaults).
    @Published var availableTags: [String] = IdeaTag.defaults

    /// Alias so existing code referencing allTags still works.
    var allTags: [String] { availableTags }

    /// Maps video ID → comments. Each video has a thread of comments.
    @Published var videoCommentsMap: [UUID: [IdeaComment]] = [:]

    var isEmpty: Bool { videos.isEmpty && folders.isEmpty }

    var unfiledVideos: [InspirationVideo] {
        videos
            .filter { videoFolderMap[$0.id] == nil }
            .sorted { $0.savedAt > $1.savedAt }
    }

    /// Returns non-archived videos for use in pickers.
    var activeVideos: [InspirationVideo] {
        videos
            .filter { $0.status != .archived }
            .sorted { $0.savedAt > $1.savedAt }
    }

    func videos(in folder: IdeaFolder) -> [InspirationVideo] {
        videos
            .filter { videoFolderMap[$0.id] == folder.id }
            .sorted { $0.savedAt > $1.savedAt }
    }

    func tags(for videoId: UUID) -> [String] {
        videoTagsMap[videoId] ?? []
    }

    /// Replaces all tags for a video. Pass an empty array to clear.
    func setTags(for videoId: UUID, tags: [String]) {
        if tags.isEmpty {
            videoTagsMap.removeValue(forKey: videoId)
        } else {
            videoTagsMap[videoId] = tags
        }
        // TODO: Update tags in Supabase
    }

    /// Toggles a tag on/off for a video.
    func toggleTag(for videoId: UUID, tag: String) {
        var current = videoTagsMap[videoId] ?? []
        if current.contains(tag) {
            current.removeAll { $0 == tag }
        } else {
            current.append(tag)
        }
        videoTagsMap[videoId] = current.isEmpty ? nil : current
    }

    /// Adds a new tag to the available tags list.
    func addCustomTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !availableTags.contains(trimmed) else { return }
        availableTags.append(trimmed)
    }

    /// Removes a tag from the available list and from all videos that have it.
    func removeAvailableTag(_ tag: String) {
        availableTags.removeAll { $0 == tag }
        // Remove this tag from any videos that had it
        for (videoId, tags) in videoTagsMap {
            let filtered = tags.filter { $0 != tag }
            videoTagsMap[videoId] = filtered.isEmpty ? nil : filtered
        }
    }

    /// Returns comments for a video, sorted oldest first (chat order).
    func comments(for videoId: UUID) -> [IdeaComment] {
        (videoCommentsMap[videoId] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    /// Adds a new comment to a video's thread.
    func addComment(to videoId: UUID, text: String, authorName: String = "You") {
        let comment = IdeaComment(inspirationVideoId: videoId, authorName: authorName, text: text)
        videoCommentsMap[videoId, default: []].append(comment)
    }

    /// Updates the text of an existing comment.
    func updateComment(id commentId: UUID, videoId: UUID, newText: String) {
        guard var comments = videoCommentsMap[videoId],
              let index = comments.firstIndex(where: { $0.id == commentId })
        else { return }
        comments[index].text = newText
        videoCommentsMap[videoId] = comments
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

    // MARK: - Delete Video

    /// Removes an idea and all its associated data (folder mapping, tags, comments).
    /// Call StorybankViewModel.removeReferences(for:) separately to clean up
    /// any story references pointing to this video.
    func deleteVideo(_ videoId: UUID) {
        videos.removeAll { $0.id == videoId }
        videoFolderMap.removeValue(forKey: videoId)
        videoTagsMap.removeValue(forKey: videoId)
        videoCommentsMap.removeValue(forKey: videoId)
    }

    // MARK: - Refresh

    func refresh() async {
        await fetchVideos()
    }
}
