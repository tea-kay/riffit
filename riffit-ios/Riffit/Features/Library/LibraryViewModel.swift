import SwiftUI
import Supabase

/// Manages the ideas list, folders, and tags.
/// All mutations use optimistic UI updates — local state changes first,
/// then the Supabase call is awaited before returning.
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var videos: [InspirationVideo] = []
    @Published var folders: [IdeaFolder] = []
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var error: Error?
    @Published var hasLoadedOnce: Bool = false

    /// True while any mutation is in flight — fetchVideos skips if set
    /// to prevent a re-fetch from clobbering optimistic local state.
    @Published private(set) var isMutating: Bool = false
    private var activeMutations: Int = 0
    private func beginMutation() { activeMutations += 1; isMutating = true }
    private func endMutation() { activeMutations -= 1; if activeMutations <= 0 { activeMutations = 0; isMutating = false } }

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

    // MARK: - JSON Decoder

    /// Shared decoder for Supabase responses. Does NOT use convertFromSnakeCase
    /// because models already have explicit CodingKeys with snake_case mapping.
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            if let date = f1.date(from: str) { return date }
            if let date = f2.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return d
    }()

    // MARK: - Fetch

    /// Fetches all ideas for the current user plus comments, folders, folder mappings, and tags.
    /// TODO: creator_profile_id is user.id for now (1:1 until onboarding creates real profiles).
    func fetchVideos(userId: UUID? = nil) async {
        guard let profileId = userId else {
            isLoading = false
            // Do NOT set hasLoadedOnce — no data was fetched.
            // .task or .onChange can retry when userId becomes available.
            return
        }
        // Skip fetch if a mutation is in flight — local state is authoritative
        guard !isMutating else { return }
        // Only show loading indicator on initial fetch — refreshes are silent
        if !hasLoadedOnce {
            isLoading = true
        }
        error = nil

        do {
            // 1. Fetch videos
            let videosData = try await supabase
                .from("inspiration_videos")
                .select()
                .eq("creator_profile_id", value: profileId)
                .order("created_at", ascending: false)
                .execute()
                .data
            self.videos = try Self.decoder.decode([InspirationVideo].self, from: videosData)

            let videoIds = videos.map { $0.id }

            // 2. Fetch folders
            let foldersData = try await supabase
                .from("inspiration_folders")
                .select()
                .eq("user_id", value: profileId)
                .execute()
                .data
            self.folders = try Self.decoder.decode([IdeaFolder].self, from: foldersData)

            guard !videoIds.isEmpty else {
                isLoading = false
                return
            }

            // 3. Fetch comments
            let commentsData = try await supabase
                .from("idea_comments")
                .select()
                .in("inspiration_video_id", values: videoIds.map { $0.uuidString })
                .order("created_at")
                .execute()
                .data
            let allComments = try Self.decoder.decode([IdeaComment].self, from: commentsData)
            self.videoCommentsMap = Dictionary(grouping: allComments, by: \.inspirationVideoId)

            // 4. Fetch tags
            struct TagRow: Decodable {
                let inspirationVideoId: UUID
                let tag: String
                enum CodingKeys: String, CodingKey {
                    case inspirationVideoId = "inspiration_video_id"
                    case tag
                }
            }
            let tagsData = try await supabase
                .from("idea_tags")
                .select()
                .in("inspiration_video_id", values: videoIds.map { $0.uuidString })
                .execute()
                .data
            let allTagRows = try Self.decoder.decode([TagRow].self, from: tagsData)
            var tagsMap: [UUID: [String]] = [:]
            for row in allTagRows {
                tagsMap[row.inspirationVideoId, default: []].append(row.tag)
            }
            self.videoTagsMap = tagsMap

            // 5. Fetch folder mappings
            struct FolderMapRow: Decodable {
                let inspirationVideoId: UUID
                let folderId: UUID
                enum CodingKeys: String, CodingKey {
                    case inspirationVideoId = "inspiration_video_id"
                    case folderId = "folder_id"
                }
            }
            let mapData = try await supabase
                .from("idea_folder_map")
                .select()
                .in("inspiration_video_id", values: videoIds.map { $0.uuidString })
                .execute()
                .data
            let mapRows = try Self.decoder.decode([FolderMapRow].self, from: mapData)
            var newMap: [UUID: UUID] = [:]
            for row in mapRows {
                newMap[row.inspirationVideoId] = row.folderId
            }
            self.videoFolderMap = newMap

            // 6. Fetch user's custom tags
            struct UserTagRow: Decodable {
                let tag: String
            }
            let userTagsData = try await supabase
                .from("user_tags")
                .select()
                .eq("user_id", value: profileId)
                .execute()
                .data
            let userTagRows = try Self.decoder.decode([UserTagRow].self, from: userTagsData)
            // Merge defaults + user custom tags, preserving order, no duplicates
            var mergedTags = IdeaTag.defaults
            for row in userTagRows {
                if !mergedTags.contains(row.tag) {
                    mergedTags.append(row.tag)
                }
            }
            self.availableTags = mergedTags

        } catch {
            print("[LibraryVM] fetchVideos FAILED: \(error)")
            self.error = error
        }

        isLoading = false
        hasLoadedOnce = true
    }

    // MARK: - Add Video

    func addVideo(
        url: String,
        platform: InspirationVideo.Platform,
        title: String?,
        userNote: String?,
        tags: [String]?,
        folderId: UUID? = nil,
        userId: UUID? = nil
    ) async {
        beginMutation()
        defer { endMutation() }
        isSubmitting = true

        // TODO: creator_profile_id is user.id for now (1:1 until onboarding)
        let profileId = userId ?? UUID()

        let newVideo = InspirationVideo(
            id: UUID(),
            creatorProfileId: profileId,
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

        if let folderId {
            videoFolderMap[newVideo.id] = folderId
        }

        // Seed the first comment from the user note
        if let userNote, !userNote.isEmpty {
            let firstComment = IdeaComment(inspirationVideoId: newVideo.id, userId: userId, text: userNote)
            videoCommentsMap[newVideo.id] = [firstComment]
        }

        videos.insert(newVideo, at: 0)
        isSubmitting = false

        // Persist to Supabase — awaited so callers can dismiss after data is safe
        do {
            try await supabase.from("inspiration_videos").insert(newVideo).execute()

            // Persist tags
            if let tags, !tags.isEmpty {
                for tag in tags {
                    struct TagInsert: Encodable {
                        let inspirationVideoId: UUID
                        let tag: String
                        enum CodingKeys: String, CodingKey {
                            case inspirationVideoId = "inspiration_video_id"
                            case tag
                        }
                    }
                    try await supabase.from("idea_tags")
                        .insert(TagInsert(inspirationVideoId: newVideo.id, tag: tag))
                        .execute()
                }
            }

            // Persist folder mapping
            if let folderId {
                struct FolderMapInsert: Encodable {
                    let inspirationVideoId: UUID
                    let folderId: UUID
                    enum CodingKeys: String, CodingKey {
                        case inspirationVideoId = "inspiration_video_id"
                        case folderId = "folder_id"
                    }
                }
                try await supabase.from("idea_folder_map")
                    .insert(FolderMapInsert(inspirationVideoId: newVideo.id, folderId: folderId))
                    .execute()
            }

            // Persist first comment
            if let firstComment = videoCommentsMap[newVideo.id]?.first {
                try await supabase.from("idea_comments").insert(firstComment).execute()
            }
        } catch {
            videos.removeAll { $0.id == newVideo.id }
            videoTagsMap.removeValue(forKey: newVideo.id)
            videoFolderMap.removeValue(forKey: newVideo.id)
            videoCommentsMap.removeValue(forKey: newVideo.id)
            print("[LibraryVM] addVideo persist FAILED: \(error)")
        }
    }

    // MARK: - Update Title

    func updateTitle(for videoId: UUID, title: String) async {
        beginMutation()
        defer { endMutation() }
        guard let index = videos.firstIndex(where: { $0.id == videoId }) else { return }
        let previousTitle = videos[index].title
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        videos[index].title = trimmed.isEmpty ? nil : trimmed

        do {
            struct TitleUpdate: Encodable { let title: String? }
            try await supabase.from("inspiration_videos")
                .update(TitleUpdate(title: trimmed.isEmpty ? nil : trimmed))
                .eq("id", value: videoId)
                .execute()
        } catch {
            if let idx = videos.firstIndex(where: { $0.id == videoId }) {
                videos[idx].title = previousTitle
            }
            print("[LibraryVM] updateTitle FAILED: \(error)")
        }
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

    // MARK: - Tags

    /// Replaces all tags for a video. Pass an empty array to clear.
    func setTags(for videoId: UUID, tags: [String]) async {
        beginMutation()
        defer { endMutation() }
        let previousTags = videoTagsMap[videoId]
        if tags.isEmpty {
            videoTagsMap.removeValue(forKey: videoId)
        } else {
            videoTagsMap[videoId] = tags
        }

        do {
            // Delete existing tags, then insert new ones
            try await supabase.from("idea_tags")
                .delete()
                .eq("inspiration_video_id", value: videoId)
                .execute()
            for tag in tags {
                struct TagInsert: Encodable {
                    let inspirationVideoId: UUID
                    let tag: String
                    enum CodingKeys: String, CodingKey {
                        case inspirationVideoId = "inspiration_video_id"
                        case tag
                    }
                }
                try await supabase.from("idea_tags")
                    .insert(TagInsert(inspirationVideoId: videoId, tag: tag))
                    .execute()
            }
        } catch {
            videoTagsMap[videoId] = previousTags
            print("[LibraryVM] setTags FAILED: \(error)")
        }
    }

    /// Toggles a tag on/off for a video.
    func toggleTag(for videoId: UUID, tag: String) async {
        beginMutation()
        defer { endMutation() }
        let previousTags = videoTagsMap[videoId]
        var current = videoTagsMap[videoId] ?? []
        let wasPresent = current.contains(tag)
        if wasPresent {
            current.removeAll { $0 == tag }
        } else {
            current.append(tag)
        }
        videoTagsMap[videoId] = current.isEmpty ? nil : current

        do {
            if wasPresent {
                // Remove the tag
                try await supabase.from("idea_tags")
                    .delete()
                    .eq("inspiration_video_id", value: videoId)
                    .eq("tag", value: tag)
                    .execute()
            } else {
                // Add the tag
                struct TagInsert: Encodable {
                    let inspirationVideoId: UUID
                    let tag: String
                    enum CodingKeys: String, CodingKey {
                        case inspirationVideoId = "inspiration_video_id"
                        case tag
                    }
                }
                try await supabase.from("idea_tags")
                    .insert(TagInsert(inspirationVideoId: videoId, tag: tag))
                    .execute()
            }
        } catch {
            videoTagsMap[videoId] = previousTags
            print("[LibraryVM] toggleTag FAILED: \(error)")
        }
    }

    /// Adds a new tag to the available tags list.
    func addCustomTag(_ tag: String, userId: UUID? = nil) async {
        beginMutation()
        defer { endMutation() }
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !availableTags.contains(trimmed) else { return }
        availableTags.append(trimmed)

        guard let userId else { return }
        do {
            struct UserTagInsert: Encodable {
                let userId: UUID
                let tag: String
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case tag
                }
            }
            try await supabase.from("user_tags")
                .insert(UserTagInsert(userId: userId, tag: trimmed))
                .execute()
        } catch {
            availableTags.removeAll { $0 == trimmed }
            print("[LibraryVM] addCustomTag FAILED: \(error)")
        }
    }

    /// Removes a tag from the available list and from all videos that have it.
    func removeAvailableTag(_ tag: String, userId: UUID? = nil) async {
        beginMutation()
        defer { endMutation() }
        let previousAvailableTags = availableTags
        let previousVideoTagsMap = videoTagsMap
        availableTags.removeAll { $0 == tag }
        // Remove this tag from any videos that had it
        for (videoId, tags) in videoTagsMap {
            let filtered = tags.filter { $0 != tag }
            videoTagsMap[videoId] = filtered.isEmpty ? nil : filtered
        }

        do {
            // Remove from all videos
            try await supabase.from("idea_tags")
                .delete()
                .eq("tag", value: tag)
                .execute()
            // Remove from user's custom tags
            if let userId {
                try await supabase.from("user_tags")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("tag", value: tag)
                    .execute()
            }
        } catch {
            availableTags = previousAvailableTags
            videoTagsMap = previousVideoTagsMap
            print("[LibraryVM] removeAvailableTag FAILED: \(error)")
        }
    }

    // MARK: - Comments

    /// Returns comments for a video, sorted oldest first (chat order).
    func comments(for videoId: UUID) -> [IdeaComment] {
        (videoCommentsMap[videoId] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    /// Adds a new comment to a video's thread.
    func addComment(to videoId: UUID, text: String, authorName: String = "You", userId: UUID? = nil) async {
        beginMutation()
        defer { endMutation() }
        let comment = IdeaComment(inspirationVideoId: videoId, userId: userId, authorName: authorName, text: text)
        videoCommentsMap[videoId, default: []].append(comment)

        do {
            try await supabase.from("idea_comments").insert(comment).execute()
        } catch {
            videoCommentsMap[videoId]?.removeAll { $0.id == comment.id }
            print("[LibraryVM] addComment FAILED: \(error)")
        }
    }

    /// Updates the text of an existing comment.
    func updateComment(id commentId: UUID, videoId: UUID, newText: String) async {
        beginMutation()
        defer { endMutation() }
        guard var comments = videoCommentsMap[videoId],
              let index = comments.firstIndex(where: { $0.id == commentId })
        else { return }
        let previousText = comments[index].text
        comments[index].text = newText
        videoCommentsMap[videoId] = comments

        do {
            struct TextUpdate: Encodable { let text: String }
            try await supabase.from("idea_comments")
                .update(TextUpdate(text: newText))
                .eq("id", value: commentId)
                .execute()
        } catch {
            if var cs = videoCommentsMap[videoId],
               let idx = cs.firstIndex(where: { $0.id == commentId }) {
                cs[idx].text = previousText
                videoCommentsMap[videoId] = cs
            }
            print("[LibraryVM] updateComment FAILED: \(error)")
        }
    }

    // MARK: - Folders

    func createFolder(name: String, userId: UUID? = nil) async {
        beginMutation()
        defer { endMutation() }
        let folder = IdeaFolder(userId: userId, name: name)
        folders.append(folder)

        do {
            try await supabase.from("inspiration_folders").insert(folder).execute()
        } catch {
            folders.removeAll { $0.id == folder.id }
            print("[LibraryVM] createFolder FAILED: \(error)")
        }
    }

    func renameFolder(_ folder: IdeaFolder, to name: String) async {
        beginMutation()
        defer { endMutation() }
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        let previousName = folders[index].name
        folders[index].name = name

        do {
            struct NameUpdate: Encodable { let name: String }
            try await supabase.from("inspiration_folders")
                .update(NameUpdate(name: name))
                .eq("id", value: folder.id)
                .execute()
        } catch {
            if let idx = folders.firstIndex(where: { $0.id == folder.id }) {
                folders[idx].name = previousName
            }
            print("[LibraryVM] renameFolder FAILED: \(error)")
        }
    }

    func deleteFolder(_ folder: IdeaFolder) async {
        beginMutation()
        defer { endMutation() }
        let snapshotFolders = folders
        let snapshotFolderMap = videoFolderMap
        let unfiledVideoIds = videoFolderMap.filter { $0.value == folder.id }.map { $0.key }
        for videoId in unfiledVideoIds {
            videoFolderMap.removeValue(forKey: videoId)
        }
        folders.removeAll { $0.id == folder.id }

        do {
            // CASCADE on idea_folder_map handles unmapping
            try await supabase.from("inspiration_folders")
                .delete()
                .eq("id", value: folder.id)
                .execute()
        } catch {
            folders = snapshotFolders
            videoFolderMap = snapshotFolderMap
            print("[LibraryVM] deleteFolder FAILED: \(error)")
        }
    }

    func moveVideo(_ videoId: UUID, to folderId: UUID?) async {
        beginMutation()
        defer { endMutation() }
        let previousFolderId = videoFolderMap[videoId]
        if let folderId {
            videoFolderMap[videoId] = folderId
        } else {
            videoFolderMap.removeValue(forKey: videoId)
        }

        do {
            if let folderId {
                struct FolderMapRow: Encodable {
                    let inspirationVideoId: UUID
                    let folderId: UUID
                    enum CodingKeys: String, CodingKey {
                        case inspirationVideoId = "inspiration_video_id"
                        case folderId = "folder_id"
                    }
                }
                try await supabase.from("idea_folder_map")
                    .upsert(FolderMapRow(inspirationVideoId: videoId, folderId: folderId))
                    .execute()
            } else {
                try await supabase.from("idea_folder_map")
                    .delete()
                    .eq("inspiration_video_id", value: videoId)
                    .execute()
            }
        } catch {
            if let previousFolderId {
                videoFolderMap[videoId] = previousFolderId
            } else {
                videoFolderMap.removeValue(forKey: videoId)
            }
            print("[LibraryVM] moveVideo FAILED: \(error)")
        }
    }

    // MARK: - Delete Video

    /// Removes an idea and all its associated data (folder mapping, tags, comments).
    /// Call StorybankViewModel.removeReferences(for:) separately to clean up
    /// any story references pointing to this video.
    func deleteVideo(_ videoId: UUID) async {
        beginMutation()
        defer { endMutation() }
        // Snapshot for rollback
        let snapshotVideos = videos
        let snapshotFolderMap = videoFolderMap[videoId]
        let snapshotTags = videoTagsMap[videoId]
        let snapshotComments = videoCommentsMap[videoId]

        // Remove from local arrays immediately so UI never shows the deleted video
        videos.removeAll { $0.id == videoId }
        videoFolderMap.removeValue(forKey: videoId)
        videoTagsMap.removeValue(forKey: videoId)
        videoCommentsMap.removeValue(forKey: videoId)

        // 2. Await the Supabase DELETE so it completes before any re-fetch
        do {
            // CASCADE handles comments, tags, folder mappings
            try await supabase.from("inspiration_videos")
                .delete()
                .eq("id", value: videoId)
                .execute()
        } catch {
            videos = snapshotVideos
            if let snapshotFolderMap { videoFolderMap[videoId] = snapshotFolderMap }
            videoTagsMap[videoId] = snapshotTags
            videoCommentsMap[videoId] = snapshotComments
            print("[LibraryVM] deleteVideo FAILED: \(error)")
        }
    }

    // MARK: - Refresh

    func refresh(userId: UUID? = nil) async {
        await fetchVideos(userId: userId)
    }
}
