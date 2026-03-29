import SwiftUI
import Supabase

/// Manages the Storybank: stories, their assets, and references.
/// All mutations use optimistic UI updates — local state changes first,
/// then a background Supabase call. If the Supabase call fails, the
/// error is logged (proper error handling/revert is a future enhancement).
@MainActor
class StorybankViewModel: ObservableObject {

    /// Supabase JSON decoder configured for snake_case + ISO 8601 dates.
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Models already have explicit CodingKeys with snake_case mapping,
        // so do NOT use .convertFromSnakeCase (double-conversion breaks decoding).
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // Try ISO 8601 with fractional seconds first, then without
            let formatters: [ISO8601DateFormatter] = {
                let f1 = ISO8601DateFormatter()
                f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let f2 = ISO8601DateFormatter()
                f2.formatOptions = [.withInternetDateTime]
                return [f1, f2]
            }()
            for formatter in formatters {
                if let date = formatter.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return d
    }()

    @Published var stories: [Story] = []
    @Published var folders: [StoryFolder] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?
    @Published var hasLoadedOnce: Bool = false
    @Published var hasLoadedSharedOnce: Bool = false

    /// True while any mutation is in flight — fetchStories skips if set
    /// to prevent a re-fetch from clobbering optimistic local state.
    @Published private(set) var isMutating: Bool = false
    private var activeMutations: Int = 0
    private func beginMutation() { activeMutations += 1; isMutating = true }
    private func endMutation() { activeMutations -= 1; if activeMutations <= 0 { activeMutations = 0; isMutating = false } }

    /// The current user's ID, stored when fetchStories runs so that
    /// fetchSharedStories can use it without a parameter.
    private var currentUserId: UUID?

    /// Maps story ID → folder ID. Stories not in this dictionary are unfiled.
    @Published var storyFolderMap: [UUID: UUID] = [:]

    /// Maps story ID → assets, ordered by displayOrder.
    @Published var storyAssetsMap: [UUID: [StoryAsset]] = [:]

    /// Maps story ID → references.
    @Published var storyReferencesMap: [UUID: [StoryReference]] = [:]

    /// Maps story ID → asset sections.
    @Published var storySectionsMap: [UUID: [AssetSection]] = [:]

    /// Maps story ID → notes thread.
    @Published var storyNotesMap: [UUID: [StoryNote]] = [:]

    /// IDs of stories where the current user is a non-owner collaborator.
    /// Used to exclude shared stories from the owned stories sections.
    /// Filters out owner records so owned stories are never accidentally excluded.
    private var sharedStoryIds: Set<UUID> {
        Set(sharedCollaborations.filter { $0.role != .owner }.map { $0.storyId })
    }

    var isEmpty: Bool { stories.isEmpty && folders.isEmpty }

    /// Whether a story is shared (current user is a non-owner collaborator).
    func isSharedStory(_ storyId: UUID) -> Bool {
        sharedStoryIds.contains(storyId)
    }

    var unfiledStories: [Story] {
        stories.filter { storyFolderMap[$0.id] == nil && !sharedStoryIds.contains($0.id) }
    }

    func stories(in folder: StoryFolder) -> [Story] {
        stories.filter { storyFolderMap[$0.id] == folder.id && !sharedStoryIds.contains($0.id) }
    }

    // MARK: - Flat Rows

    /// Each row in the assets list is either a section header or an asset.
    /// A single ForEach drives the whole list with .onMove, enabling
    /// cross-section drag by reassigning sectionIDs after each move.
    enum AssetFlatRow: Identifiable {
        case sectionHeader(AssetSection)
        case asset(StoryAsset)

        var id: UUID {
            switch self {
            case .sectionHeader(let section): return section.id
            case .asset(let asset): return asset.id
            }
        }
    }

    /// Builds a flat interleaved array: unsectioned assets first,
    /// then each section header followed by its assets. This is
    /// what the view's ForEach iterates over.
    func flatRows(for storyId: UUID) -> [AssetFlatRow] {
        let allAssets = assets(for: storyId)
        let sections = (storySectionsMap[storyId] ?? []).sorted { $0.displayOrder < $1.displayOrder }

        var rows: [AssetFlatRow] = []

        // Unsectioned assets first (sectionId == nil)
        let unsectioned = allAssets.filter { $0.sectionId == nil }
        for asset in unsectioned {
            rows.append(.asset(asset))
        }

        // Each section header followed by its assets
        for section in sections {
            rows.append(.sectionHeader(section))
            let sectionAssets = allAssets.filter { $0.sectionId == section.id }
            for asset in sectionAssets {
                rows.append(.asset(asset))
            }
        }

        return rows
    }

    /// After a drag reorder, walk the flat array top-to-bottom and
    /// reassign each asset's sectionID based on the last section header
    /// seen above it. This is what enables cross-section drag.
    func applyFlatRowOrder(for storyId: UUID, reordered rows: [AssetFlatRow]) async {
        beginMutation()
        defer { endMutation() }
        var currentSectionId: UUID? = nil
        var newAssets: [StoryAsset] = []
        var sectionOrder: Int = 0

        for row in rows {
            switch row {
            case .sectionHeader(let section):
                // Update section display order
                if var sections = storySectionsMap[storyId],
                   let index = sections.firstIndex(where: { $0.id == section.id }) {
                    sections[index].displayOrder = sectionOrder
                    storySectionsMap[storyId] = sections
                }
                sectionOrder += 1
                currentSectionId = section.id

            case .asset(var asset):
                asset.sectionId = currentSectionId
                asset.displayOrder = newAssets.count
                newAssets.append(asset)
            }
        }

        storyAssetsMap[storyId] = newAssets
        await touchStory(storyId)

        // Persist reordered assets + sections to Supabase
        await saveAssetOrder(for: storyId)
        // Also persist section display orders
        struct SectionOrderUpdate: Encodable {
            let displayOrder: Int
            enum CodingKeys: String, CodingKey { case displayOrder = "display_order" }
        }
        let sections = self.sections(for: storyId)
        for section in sections {
            do {
                try await supabase.from("asset_sections")
                    .update(SectionOrderUpdate(displayOrder: section.displayOrder))
                    .eq("id", value: section.id)
                    .execute()
            } catch {
                print("[StorybankVM] saveSectionOrder FAILED for \(section.id): \(error)")
            }
        }
    }

    // MARK: - Fetch

    /// Fetches all stories for the current user plus their related data
    /// (assets, sections, references, notes, folders) in batch queries.
    /// TODO: creator_profile_id is user.id for now (1:1 until onboarding creates real profiles).
    func fetchStories(userId: UUID? = nil) async {
        guard let profileId = userId else {
            isLoading = false
            // Do NOT set hasLoadedOnce — no data was fetched.
            // .task or .onChange can retry when userId becomes available.
            return
        }
        self.currentUserId = profileId
        // Skip fetch if a mutation is in flight — local state is authoritative
        guard !isMutating else { return }
        // Only show loading indicator on initial fetch — refreshes are silent
        if !hasLoadedOnce {
            isLoading = true
        }
        error = nil

        var ownedStories: [Story] = []
        var sharedStories: [Story] = []

        // ── Phase 1: Owned stories + shared collab records in parallel ──
        // These are independent queries — fire both at once.
        do {
            async let ownedQuery = supabase
                .from("stories")
                .select()
                .eq("creator_profile_id", value: profileId)
                .order("updated_at", ascending: false)
                .execute()
                .data
            async let collabQuery = supabase
                .from("story_collaborators")
                .select()
                .eq("user_id", value: profileId)
                .neq("role", value: "owner")
                .execute()
                .data

            let (ownedData, collabData) = try await (ownedQuery, collabQuery)
            ownedStories = try Self.decoder.decode([Story].self, from: ownedData)
            let collaborators = try Self.decoder.decode([StoryCollaborator].self, from: collabData)
            self.sharedCollaborations = collaborators
            print("[DEBUG] Phase 1: \(ownedStories.count) owned stories, \(collaborators.count) collab records")
        } catch {
            print("[StorybankVM] Phase 1 FAILED: \(error)")
            self.error = error
        }

        let ownedIds: [String] = ownedStories.map { $0.id.uuidString }
        let sharedIds: [String] = self.sharedCollaborations.map { $0.storyId.uuidString }

        // ── Phase 2: All sub-data in parallel ──
        // Owned sub-data (assets, sections, refs, notes, folders, folder maps)
        // + shared data (story objects, assets, refs, notes) — all independent.
        // We know the shared story IDs from collab records, so no need to wait.

        // Decode helper for folder mappings
        struct FolderMapRow: Decodable {
            let storyId: UUID
            let folderId: UUID
            enum CodingKeys: String, CodingKey {
                case storyId = "story_id"
                case folderId = "folder_id"
            }
        }

        if !ownedIds.isEmpty && !sharedIds.isEmpty {
            // Both owned and shared — fire all 10 queries in parallel
            do {
                async let assetsQ = supabase.from("story_assets").select()
                    .in("story_id", values: ownedIds).order("display_order").execute().data
                async let sectionsQ = supabase.from("asset_sections").select()
                    .in("story_id", values: ownedIds).order("display_order").execute().data
                async let refsQ = supabase.from("story_references").select()
                    .in("story_id", values: ownedIds).order("display_order").execute().data
                async let notesQ = supabase.from("story_notes").select()
                    .in("story_id", values: ownedIds).order("created_at").execute().data
                async let foldersQ = supabase.from("story_folders").select()
                    .eq("user_id", value: profileId).execute().data
                async let folderMapQ = supabase.from("story_folder_map").select()
                    .in("story_id", values: ownedIds).execute().data
                async let sharedStoriesQ = supabase.from("stories").select()
                    .in("id", values: sharedIds).execute().data
                async let sharedAssetsQ = supabase.from("story_assets").select()
                    .in("story_id", values: sharedIds).order("display_order").execute().data
                async let sharedRefsQ = supabase.from("story_references").select()
                    .in("story_id", values: sharedIds).order("display_order").execute().data
                async let sharedNotesQ = supabase.from("story_notes").select()
                    .in("story_id", values: sharedIds).order("created_at").execute().data

                let (aData, sData, rData, nData, fData, fmData, ssData, saData, srData, snData) =
                    try await (assetsQ, sectionsQ, refsQ, notesQ, foldersQ, folderMapQ,
                               sharedStoriesQ, sharedAssetsQ, sharedRefsQ, sharedNotesQ)

                // Decode owned sub-data
                self.storyAssetsMap = Dictionary(grouping: try Self.decoder.decode([StoryAsset].self, from: aData), by: \.storyId)
                self.storySectionsMap = Dictionary(grouping: try Self.decoder.decode([AssetSection].self, from: sData), by: \.storyId)
                self.storyReferencesMap = Dictionary(grouping: try Self.decoder.decode([StoryReference].self, from: rData), by: \.storyId)
                self.storyNotesMap = Dictionary(grouping: try Self.decoder.decode([StoryNote].self, from: nData), by: \.storyId)
                self.folders = try Self.decoder.decode([StoryFolder].self, from: fData)
                let mapRows = try Self.decoder.decode([FolderMapRow].self, from: fmData)
                var newMap: [UUID: UUID] = [:]
                for row in mapRows { newMap[row.storyId] = row.folderId }
                self.storyFolderMap = newMap

                // Decode shared sub-data
                sharedStories = try Self.decoder.decode([Story].self, from: ssData)
                for (storyId, assets) in Dictionary(grouping: try Self.decoder.decode([StoryAsset].self, from: saData), by: \.storyId) {
                    self.storyAssetsMap[storyId] = assets
                }
                for (storyId, refs) in Dictionary(grouping: try Self.decoder.decode([StoryReference].self, from: srData), by: \.storyId) {
                    self.storyReferencesMap[storyId] = refs
                }
                for (storyId, notes) in Dictionary(grouping: try Self.decoder.decode([StoryNote].self, from: snData), by: \.storyId) {
                    self.storyNotesMap[storyId] = notes
                }
                print("[DEBUG] Phase 2: owned + shared sub-data loaded")
            } catch {
                print("[StorybankVM] Phase 2 FAILED: \(error)")
            }
        } else if !ownedIds.isEmpty {
            // Owned only — 6 queries in parallel
            do {
                async let assetsQ = supabase.from("story_assets").select()
                    .in("story_id", values: ownedIds).order("display_order").execute().data
                async let sectionsQ = supabase.from("asset_sections").select()
                    .in("story_id", values: ownedIds).order("display_order").execute().data
                async let refsQ = supabase.from("story_references").select()
                    .in("story_id", values: ownedIds).order("display_order").execute().data
                async let notesQ = supabase.from("story_notes").select()
                    .in("story_id", values: ownedIds).order("created_at").execute().data
                async let foldersQ = supabase.from("story_folders").select()
                    .eq("user_id", value: profileId).execute().data
                async let folderMapQ = supabase.from("story_folder_map").select()
                    .in("story_id", values: ownedIds).execute().data

                let (aData, sData, rData, nData, fData, fmData) =
                    try await (assetsQ, sectionsQ, refsQ, notesQ, foldersQ, folderMapQ)

                self.storyAssetsMap = Dictionary(grouping: try Self.decoder.decode([StoryAsset].self, from: aData), by: \.storyId)
                self.storySectionsMap = Dictionary(grouping: try Self.decoder.decode([AssetSection].self, from: sData), by: \.storyId)
                self.storyReferencesMap = Dictionary(grouping: try Self.decoder.decode([StoryReference].self, from: rData), by: \.storyId)
                self.storyNotesMap = Dictionary(grouping: try Self.decoder.decode([StoryNote].self, from: nData), by: \.storyId)
                self.folders = try Self.decoder.decode([StoryFolder].self, from: fData)
                let mapRows = try Self.decoder.decode([FolderMapRow].self, from: fmData)
                var newMap: [UUID: UUID] = [:]
                for row in mapRows { newMap[row.storyId] = row.folderId }
                self.storyFolderMap = newMap
                print("[DEBUG] Phase 2: owned sub-data loaded")
            } catch {
                print("[StorybankVM] Phase 2 (owned) FAILED: \(error)")
            }
        } else if !sharedIds.isEmpty {
            // Shared only — 4 queries in parallel
            do {
                async let sharedStoriesQ = supabase.from("stories").select()
                    .in("id", values: sharedIds).execute().data
                async let sharedAssetsQ = supabase.from("story_assets").select()
                    .in("story_id", values: sharedIds).order("display_order").execute().data
                async let sharedRefsQ = supabase.from("story_references").select()
                    .in("story_id", values: sharedIds).order("display_order").execute().data
                async let sharedNotesQ = supabase.from("story_notes").select()
                    .in("story_id", values: sharedIds).order("created_at").execute().data

                let (ssData, saData, srData, snData) =
                    try await (sharedStoriesQ, sharedAssetsQ, sharedRefsQ, sharedNotesQ)

                sharedStories = try Self.decoder.decode([Story].self, from: ssData)
                for (storyId, assets) in Dictionary(grouping: try Self.decoder.decode([StoryAsset].self, from: saData), by: \.storyId) {
                    self.storyAssetsMap[storyId] = assets
                }
                for (storyId, refs) in Dictionary(grouping: try Self.decoder.decode([StoryReference].self, from: srData), by: \.storyId) {
                    self.storyReferencesMap[storyId] = refs
                }
                for (storyId, notes) in Dictionary(grouping: try Self.decoder.decode([StoryNote].self, from: snData), by: \.storyId) {
                    self.storyNotesMap[storyId] = notes
                }
                print("[DEBUG] Phase 2: shared sub-data loaded")
            } catch {
                print("[StorybankVM] Phase 2 (shared) FAILED: \(error)")
            }
        }

        // ── Single assignment — self.stories written exactly once ──
        self.stories = ownedStories + sharedStories
        hasLoadedSharedOnce = true

        // ── Phase 3: Owned collaborators + batch user info (parallel) ──
        // Fetch collaborator records AND all user display info in one pass
        // so avatars are ready before hasLoadedOnce flips and the view renders.
        var allUserIdsToCache: Set<UUID> = Set(sharedStories.map { $0.creatorProfileId })

        if !ownedIds.isEmpty {
            do {
                let data = try await supabase
                    .from("story_collaborators")
                    .select()
                    .in("story_id", values: ownedIds)
                    .execute()
                    .data
                let allCollabs = try Self.decoder.decode([StoryCollaborator].self, from: data)
                let grouped = Dictionary(grouping: allCollabs, by: \.storyId)
                for (storyId, collabs) in grouped {
                    self.storyCollaboratorsMap[storyId] = collabs
                }
                allUserIdsToCache.formUnion(allCollabs.map { $0.userId })
                print("[StorybankVM] fetchOwnedCollaborators OK — \(allCollabs.count) records across \(grouped.count) stories")
            } catch {
                print("[StorybankVM] fetchOwnedCollaborators FAILED: \(error)")
            }
        }

        // Batch-fetch display names + avatars for all users we need,
        // skipping any already cached. Single query instead of N fire-and-forget Tasks.
        let uncachedIds = allUserIdsToCache.filter { collaboratorUserInfo[$0] == nil }
        if !uncachedIds.isEmpty {
            await batchCacheUserInfo(userIds: Array(uncachedIds))
        }

        isLoading = false
        hasLoadedOnce = true
    }

    // MARK: - Stories

    /// Creates a story locally and persists to Supabase.
    /// TODO: creator_profile_id is user.id for now (1:1 until onboarding).
    func createStory(title: String, userId: UUID? = nil) async {
        beginMutation()
        defer { endMutation() }
        let profileId = userId ?? UUID()
        let story = Story(creatorProfileId: profileId, title: title)
        stories.insert(story, at: 0)

        // Create an owner collaborator record locally so the People section works immediately
        let ownerCollab = StoryCollaborator(
            storyId: story.id,
            userId: profileId,
            role: .owner,
            status: .accepted,
            acceptedAt: Date()
        )
        storyCollaboratorsMap[story.id, default: []].insert(ownerCollab, at: 0)
        print("[DEBUG] createStory inserted '\(title)', stories.count = \(stories.count)")

        do {
            try await supabase.from("stories").insert(story).execute()
            // Persist owner collaborator record so collaborators can see the owner
            try await supabase.from("story_collaborators").insert(ownerCollab).execute()
        } catch {
            print("[StorybankVM] createStory FAILED: \(error)")
        }
    }

    func deleteStory(_ story: Story) async {
        // 1. Remove from local arrays immediately so UI never shows the deleted story
        storyAssetsMap.removeValue(forKey: story.id)
        storyReferencesMap.removeValue(forKey: story.id)
        storySectionsMap.removeValue(forKey: story.id)
        storyNotesMap.removeValue(forKey: story.id)
        storyFolderMap.removeValue(forKey: story.id)
        storyCollaboratorsMap.removeValue(forKey: story.id)
        stories.removeAll { $0.id == story.id }
        print("[DEBUG] deleteStory removed '\(story.title)', stories.count = \(stories.count)")

        // 2. Await the Supabase DELETE so it completes before dismiss triggers a re-fetch
        do {
            // CASCADE handles assets, sections, references, notes
            try await supabase.from("stories").delete().eq("id", value: story.id).execute()
        } catch {
            print("[StorybankVM] deleteStory FAILED: \(error)")
        }
    }

    /// Creates a copy of a story with all its assets, references, sections, and notes.
    func duplicateStory(_ story: Story) async {
        beginMutation()
        defer { endMutation() }
        let newStory = Story(
            creatorProfileId: story.creatorProfileId,
            title: story.title + " Copy"
        )
        stories.insert(newStory, at: 0)
        print("[DEBUG] duplicateStory inserted '\(newStory.title)', stories.count = \(stories.count)")

        // Duplicate sections with ID mapping so assets land in the right copied section
        var sectionIdMap: [UUID: UUID] = [:]
        if let sections = storySectionsMap[story.id] {
            var copiedSections: [AssetSection] = []
            for section in sections {
                let newSection = AssetSection(
                    storyId: newStory.id,
                    name: section.name,
                    displayOrder: section.displayOrder
                )
                sectionIdMap[section.id] = newSection.id
                copiedSections.append(newSection)
            }
            storySectionsMap[newStory.id] = copiedSections
        }

        // Duplicate assets, remapping sectionIds
        if let assets = storyAssetsMap[story.id] {
            storyAssetsMap[newStory.id] = assets.map { asset in
                StoryAsset(
                    storyId: newStory.id,
                    assetType: asset.assetType,
                    name: asset.name,
                    sectionId: asset.sectionId.flatMap { sectionIdMap[$0] },
                    contentText: asset.contentText,
                    fileUrl: asset.fileUrl,
                    durationSeconds: asset.durationSeconds,
                    displayOrder: asset.displayOrder
                )
            }
        }

        // Duplicate references
        if let refs = storyReferencesMap[story.id] {
            storyReferencesMap[newStory.id] = refs.map { ref in
                StoryReference(
                    storyId: newStory.id,
                    inspirationVideoId: ref.inspirationVideoId,
                    referenceTag: ref.referenceTag,
                    aiRelevanceNote: ref.aiRelevanceNote,
                    displayOrder: ref.displayOrder
                )
            }
        }

        // Duplicate notes
        if let notes = storyNotesMap[story.id] {
            storyNotesMap[newStory.id] = notes.map { note in
                StoryNote(storyId: newStory.id, userId: note.userId, authorName: note.authorName, text: note.text)
            }
        }

        // Persist all duplicated records to Supabase
        do {
            try await supabase.from("stories").insert(newStory).execute()
            for section in storySectionsMap[newStory.id] ?? [] {
                try await supabase.from("asset_sections").insert(section).execute()
            }
            for asset in storyAssetsMap[newStory.id] ?? [] {
                try await supabase.from("story_assets").insert(asset).execute()
            }
            for ref in storyReferencesMap[newStory.id] ?? [] {
                try await supabase.from("story_references").insert(ref).execute()
            }
            for note in storyNotesMap[newStory.id] ?? [] {
                try await supabase.from("story_notes").insert(note).execute()
            }
        } catch {
            print("[StorybankVM] duplicateStory persist FAILED: \(error)")
        }
    }

    func updateStoryTitle(_ story: Story, to title: String) async {
        beginMutation()
        defer { endMutation() }
        guard let index = stories.firstIndex(where: { $0.id == story.id }) else { return }
        stories[index].title = title
        stories[index].updatedAt = Date()

        do {
            struct TitleUpdate: Encodable {
                let title: String
                let updatedAt: String
                enum CodingKeys: String, CodingKey { case title; case updatedAt = "updated_at" }
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try await supabase.from("stories")
                .update(TitleUpdate(title: title, updatedAt: formatter.string(from: Date())))
                .eq("id", value: story.id)
                .execute()
        } catch {
            print("[StorybankVM] updateStoryTitle FAILED: \(error)")
        }
    }

    func updateStoryStatus(_ story: Story, to status: Story.Status) async {
        beginMutation()
        defer { endMutation() }
        guard let index = stories.firstIndex(where: { $0.id == story.id }) else { return }
        stories[index].status = status
        stories[index].updatedAt = Date()

        do {
            struct StatusUpdate: Encodable {
                let status: String
                let updatedAt: String
                enum CodingKeys: String, CodingKey { case status; case updatedAt = "updated_at" }
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try await supabase.from("stories")
                .update(StatusUpdate(status: status.rawValue, updatedAt: formatter.string(from: Date())))
                .eq("id", value: story.id)
                .execute()
        } catch {
            print("[StorybankVM] updateStoryStatus FAILED: \(error)")
        }
    }

    // MARK: - Assets

    func assets(for storyId: UUID) -> [StoryAsset] {
        (storyAssetsMap[storyId] ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    /// Helper: persist a new asset to Supabase after optimistic local add.
    private func persistAsset(_ asset: StoryAsset) async {
        do {
            try await supabase.from("story_assets").insert(asset).execute()
        } catch {
            print("[StorybankVM] persistAsset FAILED: \(error)")
        }
    }

    func addTextAsset(to storyId: UUID, text: String) async {
        beginMutation()
        defer { endMutation() }
        let existing = assets(for: storyId)
        let asset = StoryAsset(storyId: storyId, assetType: .text, contentText: text, displayOrder: existing.count)
        storyAssetsMap[storyId, default: []].append(asset)
        await touchStory(storyId)
        await persistAsset(asset)
    }

    func addVoiceAsset(to storyId: UUID, fileUrl: String, durationSeconds: Int, name: String? = nil) async {
        beginMutation()
        defer { endMutation() }
        let existing = assets(for: storyId)
        let asset = StoryAsset(storyId: storyId, assetType: .voiceNote, name: name, fileUrl: fileUrl, durationSeconds: durationSeconds, displayOrder: existing.count)
        storyAssetsMap[storyId, default: []].append(asset)
        await touchStory(storyId)
        await persistAsset(asset)
    }

    func addVideoAsset(to storyId: UUID, fileUrl: String, durationSeconds: Int?, name: String? = nil) async {
        beginMutation()
        defer { endMutation() }
        let existing = assets(for: storyId)
        let asset = StoryAsset(storyId: storyId, assetType: .video, name: name, fileUrl: fileUrl, durationSeconds: durationSeconds, displayOrder: existing.count)
        storyAssetsMap[storyId, default: []].append(asset)
        await touchStory(storyId)
        await persistAsset(asset)
    }

    func addImageAsset(to storyId: UUID, fileUrl: String, name: String? = nil) async {
        beginMutation()
        defer { endMutation() }
        let existing = assets(for: storyId)
        let asset = StoryAsset(storyId: storyId, assetType: .image, name: name, fileUrl: fileUrl, displayOrder: existing.count)
        storyAssetsMap[storyId, default: []].append(asset)
        await touchStory(storyId)
        await persistAsset(asset)
    }

    func updateAsset(_ asset: StoryAsset, name: String?, text: String) async {
        beginMutation()
        defer { endMutation() }
        guard let assets = storyAssetsMap[asset.storyId],
              let index = assets.firstIndex(where: { $0.id == asset.id })
        else { return }
        storyAssetsMap[asset.storyId]?[index].name = name
        storyAssetsMap[asset.storyId]?[index].contentText = text
        await touchStory(asset.storyId)

        do {
            struct AssetUpdate: Encodable {
                let name: String?
                let contentText: String?
                enum CodingKeys: String, CodingKey {
                    case name
                    case contentText = "content_text"
                }
            }
            try await supabase.from("story_assets")
                .update(AssetUpdate(name: name, contentText: text))
                .eq("id", value: asset.id)
                .execute()
        } catch {
            print("[StorybankVM] updateAsset FAILED: \(error)")
        }
    }

    func deleteAsset(_ asset: StoryAsset) async {
        beginMutation()
        defer { endMutation() }
        let storyId = asset.storyId
        storyAssetsMap[storyId]?.removeAll { $0.id == asset.id }
        if var remaining = storyAssetsMap[storyId] {
            remaining.sort { $0.displayOrder < $1.displayOrder }
            for i in remaining.indices { remaining[i].displayOrder = i }
            storyAssetsMap[storyId] = remaining
        }
        await touchStory(storyId)

        do {
            try await supabase.from("story_assets").delete().eq("id", value: asset.id).execute()
        } catch {
            print("[StorybankVM] deleteAsset FAILED: \(error)")
        }
    }

    func moveAsset(in storyId: UUID, from source: IndexSet, to destination: Int) async {
        beginMutation()
        defer { endMutation() }
        var assets = self.assets(for: storyId)
        assets.move(fromOffsets: source, toOffset: destination)
        for i in assets.indices { assets[i].displayOrder = i }
        storyAssetsMap[storyId] = assets
        await touchStory(storyId)
        await saveAssetOrder(for: storyId)
    }

    /// Persists the current display_order + section_id for all assets in a story.
    func saveAssetOrder(for storyId: UUID) async {
        struct AssetOrderUpdate: Encodable {
            let displayOrder: Int
            let sectionId: UUID?
            enum CodingKeys: String, CodingKey {
                case displayOrder = "display_order"
                case sectionId = "section_id"
            }
        }
        let ordered = assets(for: storyId)
        for asset in ordered {
            do {
                try await supabase.from("story_assets")
                    .update(AssetOrderUpdate(displayOrder: asset.displayOrder, sectionId: asset.sectionId))
                    .eq("id", value: asset.id)
                    .execute()
            } catch {
                print("[StorybankVM] saveAssetOrder FAILED for \(asset.id): \(error)")
            }
        }
    }

    // MARK: - References

    func references(for storyId: UUID) -> [StoryReference] {
        (storyReferencesMap[storyId] ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    func addReference(to storyId: UUID, videoId: UUID, tag: String) async {
        beginMutation()
        defer { endMutation() }
        let existing = references(for: storyId)
        let reference = StoryReference(storyId: storyId, inspirationVideoId: videoId, referenceTag: tag, displayOrder: existing.count)
        storyReferencesMap[storyId, default: []].append(reference)
        await touchStory(storyId)

        do {
            try await supabase.from("story_references").insert(reference).execute()
        } catch {
            print("[StorybankVM] addReference FAILED: \(error)")
        }
    }

    /// Removes all references across all stories that point to a given video.
    /// Called when an idea is deleted from the Library to prevent orphaned refs.
    func removeReferences(for videoId: UUID) {
        for storyId in storyReferencesMap.keys {
            let before = storyReferencesMap[storyId]?.count ?? 0
            storyReferencesMap[storyId]?.removeAll { $0.inspirationVideoId == videoId }
            let after = storyReferencesMap[storyId]?.count ?? 0

            // Reindex if any were removed
            if before != after {
                if var refs = storyReferencesMap[storyId] {
                    refs.sort { $0.displayOrder < $1.displayOrder }
                    for i in refs.indices {
                        refs[i].displayOrder = i
                    }
                    storyReferencesMap[storyId] = refs
                }
                Task { await self.touchStory(storyId) }
            }
        }
    }

    func deleteReference(_ reference: StoryReference) async {
        beginMutation()
        defer { endMutation() }
        storyReferencesMap[reference.storyId]?.removeAll { $0.id == reference.id }
        if var refs = storyReferencesMap[reference.storyId] {
            refs.sort { $0.displayOrder < $1.displayOrder }
            for i in refs.indices { refs[i].displayOrder = i }
            storyReferencesMap[reference.storyId] = refs
        }
        await touchStory(reference.storyId)

        do {
            try await supabase.from("story_references").delete().eq("id", value: reference.id).execute()
        } catch {
            print("[StorybankVM] deleteReference FAILED: \(error)")
        }
    }

    func moveReference(in storyId: UUID, from source: IndexSet, to destination: Int) async {
        beginMutation()
        defer { endMutation() }
        var refs = references(for: storyId)
        refs.move(fromOffsets: source, toOffset: destination)
        for i in refs.indices { refs[i].displayOrder = i }
        storyReferencesMap[storyId] = refs
        await touchStory(storyId)

        struct OrderUpdate: Encodable {
            let displayOrder: Int
            enum CodingKeys: String, CodingKey { case displayOrder = "display_order" }
        }
        for ref in refs {
            do {
                try await supabase.from("story_references")
                    .update(OrderUpdate(displayOrder: ref.displayOrder))
                    .eq("id", value: ref.id)
                    .execute()
            } catch {
                print("[StorybankVM] moveReference persist FAILED for \(ref.id): \(error)")
            }
        }
    }

    // MARK: - Asset Sections

    func sections(for storyId: UUID) -> [AssetSection] {
        (storySectionsMap[storyId] ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    func addSection(to storyId: UUID, name: String) async {
        beginMutation()
        defer { endMutation() }
        let existing = sections(for: storyId)
        let section = AssetSection(storyId: storyId, name: name, displayOrder: existing.count)
        storySectionsMap[storyId, default: []].append(section)
        await touchStory(storyId)

        do {
            try await supabase.from("asset_sections").insert(section).execute()
        } catch {
            print("[StorybankVM] addSection FAILED: \(error)")
        }
    }

    func renameSection(_ section: AssetSection, to name: String) async {
        beginMutation()
        defer { endMutation() }
        guard var sections = storySectionsMap[section.storyId],
              let index = sections.firstIndex(where: { $0.id == section.id })
        else { return }
        sections[index].name = name
        storySectionsMap[section.storyId] = sections
        await touchStory(section.storyId)

        do {
            struct NameUpdate: Encodable { let name: String }
            try await supabase.from("asset_sections")
                .update(NameUpdate(name: name))
                .eq("id", value: section.id)
                .execute()
        } catch {
            print("[StorybankVM] renameSection FAILED: \(error)")
        }
    }

    /// Deleting a section does NOT delete its assets — they become unsectioned.
    func deleteSection(_ section: AssetSection) async {
        beginMutation()
        defer { endMutation() }
        // Unfile all assets that belonged to this section
        if var assets = storyAssetsMap[section.storyId] {
            for i in assets.indices where assets[i].sectionId == section.id {
                assets[i].sectionId = nil
            }
            storyAssetsMap[section.storyId] = assets
        }

        storySectionsMap[section.storyId]?.removeAll { $0.id == section.id }

        if var sections = storySectionsMap[section.storyId] {
            sections.sort { $0.displayOrder < $1.displayOrder }
            for i in sections.indices { sections[i].displayOrder = i }
            storySectionsMap[section.storyId] = sections
        }

        await touchStory(section.storyId)

        do {
            // Unfile assets: set section_id to null
            struct NullSection: Encodable {
                let sectionId: UUID?
                enum CodingKeys: String, CodingKey { case sectionId = "section_id" }
            }
            try await supabase.from("story_assets")
                .update(NullSection(sectionId: nil))
                .eq("section_id", value: section.id)
                .execute()
            // Delete the section
            try await supabase.from("asset_sections").delete().eq("id", value: section.id).execute()
        } catch {
            print("[StorybankVM] deleteSection FAILED: \(error)")
        }
    }

    // MARK: - Story Notes

    /// Returns notes for a story, sorted oldest first (chat order).
    func notes(for storyId: UUID) -> [StoryNote] {
        (storyNotesMap[storyId] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    func addNote(to storyId: UUID, text: String, authorName: String = "You", userId: UUID? = nil) async {
        beginMutation()
        defer { endMutation() }
        let note = StoryNote(storyId: storyId, userId: userId, authorName: authorName, text: text)
        storyNotesMap[storyId, default: []].append(note)
        await touchStory(storyId)

        do {
            try await supabase.from("story_notes").insert(note).execute()
        } catch {
            print("[StorybankVM] addNote FAILED: \(error)")
        }
    }

    func updateNote(id noteId: UUID, storyId: UUID, newText: String) async {
        beginMutation()
        defer { endMutation() }
        guard var notes = storyNotesMap[storyId],
              let index = notes.firstIndex(where: { $0.id == noteId })
        else { return }
        notes[index].text = newText
        storyNotesMap[storyId] = notes
        await touchStory(storyId)

        do {
            struct TextUpdate: Encodable { let text: String }
            try await supabase.from("story_notes")
                .update(TextUpdate(text: newText))
                .eq("id", value: noteId)
                .execute()
        } catch {
            print("[StorybankVM] updateNote FAILED: \(error)")
        }
    }

    // MARK: - Invite Links

    /// Local cache of invite links, keyed by token for lookup.
    /// Populated from Supabase via fetchInviteLinks(for:) and createInviteLink().
    @Published var inviteLinks: [String: StoryInviteLink] = [:]

    /// Creates a new invite link in Supabase and caches it locally.
    /// The token is a server-generated UUID. Returns the created link,
    /// or nil if the INSERT fails.
    func createInviteLink(
        for storyId: UUID,
        createdBy: UUID,
        role: CollaboratorRole = .collaborator,
        referralUserId: UUID? = nil
    ) async -> StoryInviteLink? {
        let token = UUID().uuidString
        let link = StoryInviteLink(
            storyId: storyId,
            createdBy: createdBy,
            role: role,
            referralUserId: referralUserId,
            token: token
        )

        do {
            try await supabase.from("story_invite_links").insert(link).execute()
            // Cache locally after successful INSERT
            inviteLinks[token] = link
            print("[StorybankVM] createInviteLink OK — token: \(token)")
            return link
        } catch {
            print("[StorybankVM] createInviteLink FAILED: \(error)")
            return nil
        }
    }

    /// Fetches all invite links for a story from Supabase and caches them locally.
    /// Called when StoryDetailView appears so the owner can see existing links.
    func fetchInviteLinks(for storyId: UUID) async {
        do {
            let data = try await supabase
                .from("story_invite_links")
                .select()
                .eq("story_id", value: storyId)
                .order("created_at", ascending: false)
                .execute()
                .data
            let links = try Self.decoder.decode([StoryInviteLink].self, from: data)
            for link in links {
                inviteLinks[link.token] = link
            }
            print("[StorybankVM] fetchInviteLinks OK — \(links.count) links for story \(storyId)")
        } catch {
            print("[StorybankVM] fetchInviteLinks FAILED: \(error)")
        }
    }

    /// Returns the most recent active invite link for a story, if one exists in the local cache.
    func activeInviteLink(for storyId: UUID) -> StoryInviteLink? {
        inviteLinks.values
            .filter { $0.storyId == storyId && $0.isActive }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    /// Resolves an invite token to an invite link record + story details.
    /// Returns an AppState.ResolvedInvite if valid, sets appState.inviteError if not.
    func resolveInviteToken(_ token: String, appState: AppState) {
        // Look up the invite link by token — check local cache first
        guard let inviteLink = inviteLinks[token] else {
            // Not in cache — try fetching from Supabase
            Task {
                do {
                    let data = try await supabase
                        .from("story_invite_links")
                        .select()
                        .eq("token", value: token)
                        .single()
                        .execute()
                        .data
                    let link = try Self.decoder.decode(StoryInviteLink.self, from: data)
                    self.inviteLinks[link.token] = link
                    // Re-run resolution now that the link is cached
                    self.resolveInviteToken(token, appState: appState)
                } catch {
                    print("[StorybankVM] resolveInviteToken fetch FAILED: \(error)")
                    appState.inviteError = .notFound
                }
            }
            return
        }

        // Check if the link is still active
        guard inviteLink.isActive else {
            appState.inviteError = .expired
            return
        }

        // Check if user is already a collaborator on this story
        if let userId = appState.currentUserId {
            let existingCollabs = storyCollaboratorsMap[inviteLink.storyId] ?? []
            let sharedMatch = sharedCollaborations.first(where: { $0.storyId == inviteLink.storyId && $0.userId == userId })
            if existingCollabs.contains(where: { $0.userId == userId }) || sharedMatch != nil {
                appState.inviteError = .alreadyMember
                return
            }
        }

        // Store the referral user ID from the invite link
        appState.pendingReferralUserId = inviteLink.referralUserId

        // Look up story details for the preview — check local cache first,
        // fall back to Supabase query for stories the current user doesn't own.
        if let story = stories.first(where: { $0.id == inviteLink.storyId }) {
            let ownerInfo = collaboratorUserInfo[inviteLink.createdBy]
            appState.resolvedInvite = AppState.ResolvedInvite(
                inviteLink: inviteLink,
                storyTitle: story.title,
                ownerName: ownerInfo?.displayName ?? "Creator",
                ownerAvatarUrl: ownerInfo?.avatarUrl,
                assetCount: assets(for: inviteLink.storyId).count,
                referenceCount: references(for: inviteLink.storyId).count
            )
            appState.inviteError = nil
        } else {
            // Story not in local cache — fetch title + owner info from Supabase
            Task {
                do {
                    struct StoryRow: Decodable {
                        let title: String
                    }
                    let storyData = try await supabase
                        .from("stories")
                        .select("title")
                        .eq("id", value: inviteLink.storyId)
                        .single()
                        .execute()
                        .data
                    let storyRow = try JSONDecoder().decode(StoryRow.self, from: storyData)

                    // Fetch owner's display name + avatar
                    var ownerName = "Creator"
                    var ownerAvatarUrl: String? = nil
                    if let info = self.collaboratorUserInfo[inviteLink.createdBy] {
                        ownerName = info.displayName
                        ownerAvatarUrl = info.avatarUrl
                    } else {
                        struct UserRow: Decodable {
                            let fullName: String?
                            let username: String?
                            let avatarUrl: String?
                            let email: String?
                            enum CodingKeys: String, CodingKey {
                                case fullName = "full_name"
                                case username
                                case avatarUrl = "avatar_url"
                                case email
                            }
                        }
                        let userData = try await supabase
                            .from("users")
                            .select("full_name, username, avatar_url, email")
                            .eq("id", value: inviteLink.createdBy)
                            .single()
                            .execute()
                            .data
                        let userRow = try JSONDecoder().decode(UserRow.self, from: userData)
                        ownerName = userRow.fullName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                            ? userRow.fullName! : userRow.username ?? userRow.email?.components(separatedBy: "@").first ?? "Creator"
                        ownerAvatarUrl = userRow.avatarUrl
                    }

                    appState.resolvedInvite = AppState.ResolvedInvite(
                        inviteLink: inviteLink,
                        storyTitle: storyRow.title,
                        ownerName: ownerName,
                        ownerAvatarUrl: ownerAvatarUrl,
                        assetCount: 0,
                        referenceCount: 0
                    )
                    appState.inviteError = nil
                } catch {
                    print("[StorybankVM] resolveInviteToken story fetch FAILED: \(error)")
                    // Still show the invite with fallback title
                    appState.resolvedInvite = AppState.ResolvedInvite(
                        inviteLink: inviteLink,
                        storyTitle: "Untitled Story",
                        ownerName: "Creator",
                        ownerAvatarUrl: nil,
                        assetCount: 0,
                        referenceCount: 0
                    )
                    appState.inviteError = nil
                }
            }
        }
    }

    /// Joins a story from a resolved invite link.
    /// Creates the StoryCollaborator record and increments the invite link use_count.
    /// Optimistic local update first, then persists to Supabase in background.
    func joinStoryFromInvite(inviteLink: StoryInviteLink, userId: UUID) async {
        beginMutation()
        defer { endMutation() }
        // Create the collaborator record
        let collaborator = StoryCollaborator(
            storyId: inviteLink.storyId,
            userId: userId,
            role: inviteLink.role,
            invitedBy: inviteLink.createdBy,
            status: .accepted,
            acceptedAt: Date(),
            lastViewedAt: Date()
        )

        // Optimistic local updates
        sharedCollaborations.append(collaborator)
        storyCollaboratorsMap[inviteLink.storyId, default: []].append(collaborator)
        if var link = inviteLinks[inviteLink.token] {
            link.useCount += 1
            inviteLinks[inviteLink.token] = link
        }

        // Persist collaborator record and increment use_count in Supabase
        do {
            try await supabase.from("story_collaborators").insert(collaborator).execute()
            print("[StorybankVM] joinStoryFromInvite INSERT OK — user \(userId) → story \(inviteLink.storyId)")

            struct UseCountUpdate: Encodable {
                let useCount: Int
                enum CodingKeys: String, CodingKey { case useCount = "use_count" }
            }
            let newCount = (inviteLinks[inviteLink.token]?.useCount ?? inviteLink.useCount)
            try await supabase.from("story_invite_links")
                .update(UseCountUpdate(useCount: newCount))
                .eq("id", value: inviteLink.id)
                .execute()
            print("[StorybankVM] joinStoryFromInvite use_count UPDATE OK")
        } catch {
            print("[StorybankVM] joinStoryFromInvite FAILED: \(error)")
        }
    }

    // MARK: - Collaborators

    /// Cached user profile data for collaborators, keyed by user ID.
    /// Populated when collaborators are loaded so CollaboratorRow can
    /// display real names and avatars instead of generic placeholders.
    struct CollaboratorUserInfo {
        let displayName: String
        let avatarUrl: String?
    }
    @Published var collaboratorUserInfo: [UUID: CollaboratorUserInfo] = [:]

    /// Fetches and caches display info for a user from Supabase.
    /// Safe to call multiple times — skips if already cached.
    func cacheUserInfo(userId: UUID) {
        guard collaboratorUserInfo[userId] == nil else { return }
        Task {
            do {
                let response = try await supabase
                    .from("users")
                    .select("id, full_name, username, avatar_url, email")
                    .eq("id", value: userId)
                    .single()
                    .execute()

                struct UserRow: Decodable {
                    let id: UUID
                    let fullName: String?
                    let username: String?
                    let avatarUrl: String?
                    let email: String?
                    enum CodingKeys: String, CodingKey {
                        case id
                        case fullName = "full_name"
                        case username
                        case avatarUrl = "avatar_url"
                        case email
                    }
                }
                let row = try JSONDecoder().decode(UserRow.self, from: response.data)

                let name: String = {
                    if let fn = row.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !fn.isEmpty { return fn }
                    if let un = row.username?.trimmingCharacters(in: .whitespacesAndNewlines), !un.isEmpty { return "@\(un)" }
                    if let em = row.email, let prefix = em.components(separatedBy: "@").first, !prefix.isEmpty { return prefix }
                    return "User"
                }()

                await MainActor.run {
                    self.collaboratorUserInfo[userId] = CollaboratorUserInfo(displayName: name, avatarUrl: row.avatarUrl)
                }
            } catch {
                print("[StorybankVM] cacheUserInfo FAILED for \(userId): \(error)")
            }
        }
    }

    /// Fetches display info for multiple users in a single Supabase query and
    /// populates collaboratorUserInfo. Awaitable — callers can wait for the cache
    /// to be populated before rendering, preventing avatar pop-in.
    private func batchCacheUserInfo(userIds: [UUID]) async {
        struct UserRow: Decodable {
            let id: UUID
            let fullName: String?
            let username: String?
            let avatarUrl: String?
            let email: String?
            enum CodingKeys: String, CodingKey {
                case id
                case fullName = "full_name"
                case username
                case avatarUrl = "avatar_url"
                case email
            }
        }

        do {
            let data = try await supabase
                .from("users")
                .select("id, full_name, username, avatar_url, email")
                .in("id", values: userIds.map { $0.uuidString })
                .execute()
                .data
            let rows = try JSONDecoder().decode([UserRow].self, from: data)

            for row in rows {
                let name: String = {
                    if let fn = row.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !fn.isEmpty { return fn }
                    if let un = row.username?.trimmingCharacters(in: .whitespacesAndNewlines), !un.isEmpty { return "@\(un)" }
                    if let em = row.email, let prefix = em.components(separatedBy: "@").first, !prefix.isEmpty { return prefix }
                    return "User"
                }()
                self.collaboratorUserInfo[row.id] = CollaboratorUserInfo(displayName: name, avatarUrl: row.avatarUrl)
            }
            print("[StorybankVM] batchCacheUserInfo OK — \(rows.count) users cached")
        } catch {
            print("[StorybankVM] batchCacheUserInfo FAILED: \(error)")
        }
    }

    /// Convenience: returns display name for a collaborator, resolving from cache.
    func collaboratorDisplayName(for collaborator: StoryCollaborator, currentUserId: UUID?) -> String? {
        if collaborator.userId == currentUserId {
            return nil // let the caller use the owner display name logic
        }
        return collaboratorUserInfo[collaborator.userId]?.displayName
    }

    /// Convenience: returns avatar URL for a collaborator, resolving from cache.
    func collaboratorAvatarUrl(for collaborator: StoryCollaborator, currentUserId: UUID?) -> String? {
        if collaborator.userId == currentUserId {
            return nil // let the caller use appState.currentUser?.avatarUrl
        }
        return collaboratorUserInfo[collaborator.userId]?.avatarUrl
    }

    /// Convenience: returns avatar URL by user ID directly, for note/comment bubbles.
    func collaboratorAvatarUrl(forUserId userId: UUID?) -> String? {
        guard let userId = userId else { return nil }
        return collaboratorUserInfo[userId]?.avatarUrl
    }

    /// Maps story ID → collaborators on that story.
    @Published var storyCollaboratorsMap: [UUID: [StoryCollaborator]] = [:]

    /// Stories shared WITH the current user (where they are a non-owner collaborator).
    /// Populated from Supabase via fetchSharedStories().
    @Published var sharedCollaborations: [StoryCollaborator] = []

    /// Returns collaborators for a story, owner first, then by status + name.
    func collaborators(for storyId: UUID) -> [StoryCollaborator] {
        let all = storyCollaboratorsMap[storyId] ?? []
        return all.sorted { a, b in
            // Owner always first
            if a.role == .owner && b.role != .owner { return true }
            if b.role == .owner && a.role != .owner { return false }
            // Accepted before pending
            if a.status == .accepted && b.status != .accepted { return true }
            if b.status == .accepted && a.status != .accepted { return false }
            // Then by creation date
            return a.createdAt < b.createdAt
        }
    }

    /// Accepted shared stories, sorted by most recently updated.
    var acceptedSharedStories: [StoryCollaborator] {
        sharedCollaborations
            .filter { $0.status == .accepted }
            .sorted { a, b in
                // Sort by the story's updatedAt if we have it, otherwise by acceptedAt
                let aDate = stories.first(where: { $0.id == a.storyId })?.updatedAt ?? a.acceptedAt ?? a.createdAt
                let bDate = stories.first(where: { $0.id == b.storyId })?.updatedAt ?? b.acceptedAt ?? b.createdAt
                return aDate > bDate
            }
    }

    /// Pending invitations, newest first.
    var pendingInvites: [StoryCollaborator] {
        sharedCollaborations
            .filter { $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Whether the "Shared with me" section should be visible.
    /// Only shows if user has at least one shared or pending story.
    var hasSharedContent: Bool {
        !sharedCollaborations.isEmpty
    }

    /// Returns the current user's role for a given story, or nil if they're not a collaborator.
    /// Checks both the collaborators map (for owner) and sharedCollaborations (for non-owners).
    func currentUserRole(for storyId: UUID, userId: UUID?) -> CollaboratorRole? {
        guard let userId else { return nil }

        // Check collaborators map first (covers owner case)
        if let record = (storyCollaboratorsMap[storyId] ?? []).first(where: { $0.userId == userId }) {
            return record.role
        }

        // Check shared collaborations (covers non-owner case)
        if let record = sharedCollaborations.first(where: { $0.storyId == storyId && $0.userId == userId }) {
            return record.role
        }

        return nil
    }

    /// Whether there are unread notes on a shared story for the current user.
    /// Compares the most recent note's createdAt against the collaborator's lastViewedAt.
    func hasUnreadNotes(for storyId: UUID) -> Bool {
        guard let collab = sharedCollaborations.first(where: { $0.storyId == storyId && $0.status == .accepted }),
              let lastViewed = collab.lastViewedAt
        else {
            // If never viewed, any note means unread
            let noteCount = (storyNotesMap[storyId] ?? []).count
            // Only unread if we're a collaborator and there are notes
            let isCollab = sharedCollaborations.contains(where: { $0.storyId == storyId && $0.status == .accepted })
            return isCollab && noteCount > 0
        }

        // Check if any note was created after lastViewedAt
        let notes = storyNotesMap[storyId] ?? []
        return notes.contains { $0.createdAt > lastViewed }
    }

    /// Updates lastViewedAt to now for the current user's collaboration record.
    /// Called when a collaborator opens a shared StoryDetailView.
    func updateLastViewed(for storyId: UUID) {
        if let index = sharedCollaborations.firstIndex(where: { $0.storyId == storyId }) {
            sharedCollaborations[index].lastViewedAt = Date()
        }
        // Also update in the collaborators map if present
        if var collabs = storyCollaboratorsMap[storyId] {
            for i in collabs.indices {
                if collabs[i].storyId == storyId {
                    collabs[i].lastViewedAt = Date()
                }
            }
            storyCollaboratorsMap[storyId] = collabs
        }
    }

    /// Adds a collaborator to a story. Creates a pending invitation.
    /// Optimistic local update + Supabase INSERT in background.
    func addCollaborator(to storyId: UUID, userId: UUID, role: CollaboratorRole, invitedBy: UUID) async {
        beginMutation()
        defer { endMutation() }
        // Check for duplicate
        let existing = storyCollaboratorsMap[storyId] ?? []
        guard !existing.contains(where: { $0.userId == userId }) else { return }

        let collaborator = StoryCollaborator(
            storyId: storyId,
            userId: userId,
            role: role,
            invitedBy: invitedBy,
            status: .pending
        )
        storyCollaboratorsMap[storyId, default: []].append(collaborator)

        // Fetch and cache the new collaborator's profile data for display
        cacheUserInfo(userId: userId)

        // Persist to Supabase
        do {
            try await supabase.from("story_collaborators").insert(collaborator).execute()
            print("[StorybankVM] addCollaborator INSERT OK — user \(userId) → story \(storyId)")
        } catch {
            print("[StorybankVM] addCollaborator INSERT FAILED: \(error)")
        }
    }

    /// Removes a collaborator from a story (owner action).
    /// Optimistic local removal + Supabase DELETE in background.
    func removeCollaborator(_ collaborator: StoryCollaborator) async {
        beginMutation()
        defer { endMutation() }
        storyCollaboratorsMap[collaborator.storyId]?.removeAll { $0.id == collaborator.id }

        do {
            try await supabase.from("story_collaborators")
                .delete()
                .eq("id", value: collaborator.id)
                .execute()
            print("[StorybankVM] removeCollaborator DELETE OK — \(collaborator.id)")
        } catch {
            print("[StorybankVM] removeCollaborator DELETE FAILED: \(error)")
        }
    }

    /// Updates a collaborator's role (Studio+ feature).
    /// Optimistic local update + Supabase UPDATE in background.
    func updateCollaboratorRole(_ collaborator: StoryCollaborator, to newRole: CollaboratorRole) async {
        beginMutation()
        defer { endMutation() }
        guard var collabs = storyCollaboratorsMap[collaborator.storyId],
              let index = collabs.firstIndex(where: { $0.id == collaborator.id })
        else { return }
        collabs[index].role = newRole
        storyCollaboratorsMap[collaborator.storyId] = collabs

        do {
            struct RoleUpdate: Encodable {
                let role: String
            }
            try await supabase.from("story_collaborators")
                .update(RoleUpdate(role: newRole.rawValue))
                .eq("id", value: collaborator.id)
                .execute()
            print("[StorybankVM] updateCollaboratorRole OK — \(collaborator.id) → \(newRole.rawValue)")
        } catch {
            print("[StorybankVM] updateCollaboratorRole FAILED: \(error)")
        }
    }

    /// Fetches collaborators for a single story from Supabase.
    /// Populates storyCollaboratorsMap and caches user info for display.
    func fetchCollaborators(for storyId: UUID) async {
        do {
            let data = try await supabase
                .from("story_collaborators")
                .select()
                .eq("story_id", value: storyId)
                .execute()
                .data
            let collaborators = try Self.decoder.decode([StoryCollaborator].self, from: data)
            self.storyCollaboratorsMap[storyId] = collaborators
            // Cache display info for each collaborator
            for collab in collaborators {
                cacheUserInfo(userId: collab.userId)
            }
            print("[StorybankVM] fetchCollaborators OK — \(collaborators.count) for story \(storyId)")
        } catch {
            print("[StorybankVM] fetchCollaborators FAILED for \(storyId): \(error)")
        }
    }

    /// Fetches stories shared with the current user from Supabase.
    /// Populates sharedCollaborations, merges shared Story objects with the
    /// provided owned stories, and assigns self.stories once (single render).
    /// Also fetches assets/notes/references for counts and unread detection.
    func fetchSharedStories(ownedStories: [Story]) async {
        guard let userId = currentUserId else {
            // No user — just assign owned stories as-is
            self.stories = ownedStories
            return
        }

        do {
            // 1. Fetch collaborator records where this user is a non-owner collaborator
            let collabData = try await supabase
                .from("story_collaborators")
                .select()
                .eq("user_id", value: userId)
                .neq("role", value: "owner")
                .execute()
                .data
            let collaborators = try Self.decoder.decode([StoryCollaborator].self, from: collabData)
            self.sharedCollaborations = collaborators
            print("[DEBUG] fetchSharedStories got \(collaborators.count) collab records: \(collaborators.map { "storyId=\($0.storyId), role=\($0.role.rawValue)" })")

            let sharedIds = collaborators.map { $0.storyId }
            guard !sharedIds.isEmpty else {
                print("[StorybankVM] fetchSharedStories OK — no shared stories")
                self.stories = ownedStories
                hasLoadedSharedOnce = true
                return
            }
            let idsForQuery = sharedIds.map { $0.uuidString }

            // 2. Fetch the shared stories themselves (other users' stories)
            let storiesData = try await supabase
                .from("stories")
                .select()
                .in("id", values: idsForQuery)
                .execute()
                .data
            let fetchedSharedStories = try Self.decoder.decode([Story].self, from: storiesData)

            // Single assignment — owned + shared merged in one @Published update
            print("[DEBUG] fetchSharedStories owned: \(ownedStories.count), shared: \(fetchedSharedStories.count)")
            self.stories = ownedStories + fetchedSharedStories
            print("[DEBUG] fetchSharedStories stories AFTER merge: \(self.stories.count)")

            // 3. Fetch assets for shared stories (for counts label)
            let assetsData = try await supabase
                .from("story_assets")
                .select()
                .in("story_id", values: idsForQuery)
                .order("display_order")
                .execute()
                .data
            let sharedAssets = try Self.decoder.decode([StoryAsset].self, from: assetsData)
            for (storyId, assets) in Dictionary(grouping: sharedAssets, by: \.storyId) {
                self.storyAssetsMap[storyId] = assets
            }

            // 4. Fetch references for shared stories (for counts label)
            let refsData = try await supabase
                .from("story_references")
                .select()
                .in("story_id", values: idsForQuery)
                .order("display_order")
                .execute()
                .data
            let sharedRefs = try Self.decoder.decode([StoryReference].self, from: refsData)
            for (storyId, refs) in Dictionary(grouping: sharedRefs, by: \.storyId) {
                self.storyReferencesMap[storyId] = refs
            }

            // 5. Fetch notes for shared stories (for unread detection)
            let notesData = try await supabase
                .from("story_notes")
                .select()
                .in("story_id", values: idsForQuery)
                .order("created_at")
                .execute()
                .data
            let sharedNotes = try Self.decoder.decode([StoryNote].self, from: notesData)
            for (storyId, notes) in Dictionary(grouping: sharedNotes, by: \.storyId) {
                self.storyNotesMap[storyId] = notes
            }

            // 6. Cache owner display info for each shared story
            let ownerIds = Set(fetchedSharedStories.map { $0.creatorProfileId })
            for ownerId in ownerIds {
                cacheUserInfo(userId: ownerId)
            }

            print("[StorybankVM] fetchSharedStories OK — \(collaborators.count) collaborations, \(fetchedSharedStories.count) stories")
        } catch {
            print("[StorybankVM] fetchSharedStories FAILED: \(error)")
            // On failure, still assign owned stories so the view has data
            if self.stories.isEmpty {
                self.stories = ownedStories
            }
        }
        hasLoadedSharedOnce = true
    }

    /// Accepts a pending invite. Updates status and sets acceptedAt.
    /// Optimistic local update + Supabase UPDATE, then fetches the
    /// Story object so it appears in the Active section immediately.
    func acceptInvite(_ collaborator: StoryCollaborator) async {
        beginMutation()
        defer { endMutation() }
        let now = Date()
        if let index = sharedCollaborations.firstIndex(where: { $0.id == collaborator.id }) {
            sharedCollaborations[index].status = .accepted
            sharedCollaborations[index].acceptedAt = now
        }

        let storyId = collaborator.storyId

        // 1. Persist the accept to Supabase
        do {
            struct AcceptUpdate: Encodable {
                let status: String
                let acceptedAt: String
                enum CodingKeys: String, CodingKey {
                    case status
                    case acceptedAt = "accepted_at"
                }
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try await supabase.from("story_collaborators")
                .update(AcceptUpdate(status: "accepted", acceptedAt: formatter.string(from: now)))
                .eq("id", value: collaborator.id)
                .execute()
            print("[StorybankVM] acceptInvite UPDATE OK — \(collaborator.id)")
        } catch {
            print("[StorybankVM] acceptInvite UPDATE FAILED: \(error)")
        }

        // 2. Fetch the Story object so ActiveSection can render it
        do {
            let storyData = try await supabase
                .from("stories")
                .select()
                .eq("id", value: storyId)
                .execute()
                .data
            let fetchedStories = try Self.decoder.decode([Story].self, from: storyData)
            guard let story = fetchedStories.first else {
                print("[StorybankVM] acceptInvite — story \(storyId) not returned (RLS or deleted)")
                return
            }

            // Merge into stories array (remove stale entry if present, then append)
            self.stories.removeAll { $0.id == storyId }
            self.stories.append(story)

            // 3. Fetch assets, references, notes for counts and unread detection
            let idForQuery = [storyId.uuidString]

            let assetsData = try await supabase
                .from("story_assets")
                .select()
                .in("story_id", values: idForQuery)
                .order("display_order")
                .execute()
                .data
            self.storyAssetsMap[storyId] = try Self.decoder.decode([StoryAsset].self, from: assetsData)

            let refsData = try await supabase
                .from("story_references")
                .select()
                .in("story_id", values: idForQuery)
                .order("display_order")
                .execute()
                .data
            self.storyReferencesMap[storyId] = try Self.decoder.decode([StoryReference].self, from: refsData)

            let notesData = try await supabase
                .from("story_notes")
                .select()
                .in("story_id", values: idForQuery)
                .order("created_at")
                .execute()
                .data
            self.storyNotesMap[storyId] = try Self.decoder.decode([StoryNote].self, from: notesData)

            // 4. Cache owner display info
            cacheUserInfo(userId: story.creatorProfileId)

            print("[StorybankVM] acceptInvite — fetched story + assets for \(storyId)")
        } catch {
            print("[StorybankVM] acceptInvite — fetch story FAILED: \(error)")
        }
    }

    /// Declines a pending invite. Removes the collaborator record.
    /// Optimistic local removal + Supabase DELETE in background.
    func declineInvite(_ collaborator: StoryCollaborator) async {
        beginMutation()
        defer { endMutation() }
        sharedCollaborations.removeAll { $0.id == collaborator.id }

        do {
            try await supabase.from("story_collaborators")
                .delete()
                .eq("id", value: collaborator.id)
                .execute()
            print("[StorybankVM] declineInvite DELETE OK — \(collaborator.id)")
        } catch {
            print("[StorybankVM] declineInvite DELETE FAILED: \(error)")
        }
    }

    /// Removes the current user's collaboration record — they leave the shared story.
    /// Optimistic local removal + Supabase DELETE in background.
    func leaveStory(_ collaborator: StoryCollaborator) async {
        beginMutation()
        defer { endMutation() }
        sharedCollaborations.removeAll { $0.id == collaborator.id }
        storyCollaboratorsMap[collaborator.storyId]?.removeAll { $0.id == collaborator.id }

        do {
            try await supabase.from("story_collaborators")
                .delete()
                .eq("id", value: collaborator.id)
                .execute()
            print("[StorybankVM] leaveStory DELETE OK — \(collaborator.id)")
        } catch {
            print("[StorybankVM] leaveStory DELETE FAILED: \(error)")
        }
    }

    // ensureOwnerCollaborator removed — owner records are now created in the
    // database by createStory() and fetched by fetchCollaborators().

    // MARK: - Story Folders

    func createFolder(name: String, userId: UUID? = nil) async {
        beginMutation()
        defer { endMutation() }
        let folder = StoryFolder(userId: userId, name: name)
        folders.append(folder)

        do {
            try await supabase.from("story_folders").insert(folder).execute()
        } catch {
            print("[StorybankVM] createFolder FAILED: \(error)")
        }
    }

    func renameFolder(_ folder: StoryFolder, to name: String) async {
        beginMutation()
        defer { endMutation() }
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].name = name

        do {
            struct NameUpdate: Encodable { let name: String }
            try await supabase.from("story_folders")
                .update(NameUpdate(name: name))
                .eq("id", value: folder.id)
                .execute()
        } catch {
            print("[StorybankVM] renameFolder FAILED: \(error)")
        }
    }

    func deleteFolder(_ folder: StoryFolder) async {
        beginMutation()
        defer { endMutation() }
        // Unfile all stories in this folder locally
        let unfiledStoryIds = storyFolderMap.filter { $0.value == folder.id }.map { $0.key }
        for storyId in unfiledStoryIds {
            storyFolderMap.removeValue(forKey: storyId)
        }
        folders.removeAll { $0.id == folder.id }

        do {
            // CASCADE on story_folder_map handles unfilement
            try await supabase.from("story_folders").delete().eq("id", value: folder.id).execute()
        } catch {
            print("[StorybankVM] deleteFolder FAILED: \(error)")
        }
    }

    func moveStory(_ storyId: UUID, to folderId: UUID?) async {
        beginMutation()
        defer { endMutation() }
        if let folderId {
            storyFolderMap[storyId] = folderId
        } else {
            storyFolderMap.removeValue(forKey: storyId)
        }

        do {
            if let folderId {
                struct FolderMapRow: Encodable {
                    let storyId: UUID
                    let folderId: UUID
                    enum CodingKeys: String, CodingKey {
                        case storyId = "story_id"
                        case folderId = "folder_id"
                    }
                }
                try await supabase.from("story_folder_map")
                    .upsert(FolderMapRow(storyId: storyId, folderId: folderId))
                    .execute()
            } else {
                try await supabase.from("story_folder_map")
                    .delete()
                    .eq("story_id", value: storyId)
                    .execute()
            }
        } catch {
            print("[StorybankVM] moveStory FAILED: \(error)")
        }
    }

    // MARK: - Helpers

    /// Counts string for the story card subtitle, e.g. "3 assets · 2 references"
    func countsLabel(for storyId: UUID) -> String {
        let assetCount = assets(for: storyId).count
        let refCount = references(for: storyId).count

        var parts: [String] = []
        if assetCount > 0 {
            parts.append("\(assetCount) asset\(assetCount == 1 ? "" : "s")")
        }
        if refCount > 0 {
            parts.append("\(refCount) reference\(refCount == 1 ? "" : "s")")
        }

        return parts.isEmpty ? "Empty" : parts.joined(separator: " · ")
    }

    /// Updates the updatedAt timestamp when content changes.
    /// Also persists the timestamp to Supabase.
    private func touchStory(_ storyId: UUID) async {
        guard let index = stories.firstIndex(where: { $0.id == storyId }) else { return }
        let now = Date()
        stories[index].updatedAt = now

        do {
            struct TimestampUpdate: Encodable {
                let updatedAt: String
                enum CodingKeys: String, CodingKey { case updatedAt = "updated_at" }
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try await supabase.from("stories")
                .update(TimestampUpdate(updatedAt: formatter.string(from: now)))
                .eq("id", value: storyId)
                .execute()
        } catch {
            print("[StorybankVM] touchStory FAILED: \(error)")
        }
    }
}
