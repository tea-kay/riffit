import SwiftUI

/// Manages the Storybank: stories, their assets, and references.
@MainActor
class StorybankViewModel: ObservableObject {
    @Published var stories: [Story] = []
    @Published var folders: [StoryFolder] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

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

    var isEmpty: Bool { stories.isEmpty && folders.isEmpty }

    var unfiledStories: [Story] {
        stories.filter { storyFolderMap[$0.id] == nil }
    }

    func stories(in folder: StoryFolder) -> [Story] {
        stories.filter { storyFolderMap[$0.id] == folder.id }
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
    func applyFlatRowOrder(for storyId: UUID, reordered rows: [AssetFlatRow]) {
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
        touchStory(storyId)
    }

    // MARK: - Fetch

    func fetchStories() async {
        isLoading = true
        error = nil

        // TODO: Fetch from Supabase

        isLoading = false
    }

    // MARK: - Stories

    func createStory(title: String) {
        let story = Story(
            creatorProfileId: UUID(), // TODO: Use real creator profile ID
            title: title
        )
        stories.insert(story, at: 0)
    }

    func deleteStory(_ story: Story) {
        storyAssetsMap.removeValue(forKey: story.id)
        storyReferencesMap.removeValue(forKey: story.id)
        storySectionsMap.removeValue(forKey: story.id)
        storyNotesMap.removeValue(forKey: story.id)
        stories.removeAll { $0.id == story.id }
    }

    /// Creates a copy of a story with all its assets, references, sections, and notes.
    func duplicateStory(_ story: Story) {
        let newStory = Story(
            creatorProfileId: story.creatorProfileId,
            title: story.title + " Copy"
        )
        stories.insert(newStory, at: 0)

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
                StoryNote(storyId: newStory.id, authorName: note.authorName, text: note.text)
            }
        }
    }

    func updateStoryTitle(_ story: Story, to title: String) {
        guard let index = stories.firstIndex(where: { $0.id == story.id }) else { return }
        stories[index].title = title
        stories[index].updatedAt = Date()
    }

    func updateStoryStatus(_ story: Story, to status: Story.Status) {
        guard let index = stories.firstIndex(where: { $0.id == story.id }) else { return }
        stories[index].status = status
        stories[index].updatedAt = Date()
    }

    // MARK: - Assets

    func assets(for storyId: UUID) -> [StoryAsset] {
        (storyAssetsMap[storyId] ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    func addTextAsset(to storyId: UUID, text: String) {
        let existing = assets(for: storyId)
        let asset = StoryAsset(
            storyId: storyId,
            assetType: .text,
            contentText: text,
            displayOrder: existing.count
        )
        storyAssetsMap[storyId, default: []].append(asset)
        touchStory(storyId)
    }

    func addVoiceAsset(to storyId: UUID, fileUrl: String, durationSeconds: Int, name: String? = nil) {
        let existing = assets(for: storyId)
        let asset = StoryAsset(
            storyId: storyId,
            assetType: .voiceNote,
            name: name,
            fileUrl: fileUrl,
            durationSeconds: durationSeconds,
            displayOrder: existing.count
        )
        storyAssetsMap[storyId, default: []].append(asset)
        touchStory(storyId)
    }

    func addVideoAsset(to storyId: UUID, fileUrl: String, durationSeconds: Int?, name: String? = nil) {
        let existing = assets(for: storyId)
        let asset = StoryAsset(
            storyId: storyId,
            assetType: .video,
            name: name,
            fileUrl: fileUrl,
            durationSeconds: durationSeconds,
            displayOrder: existing.count
        )
        storyAssetsMap[storyId, default: []].append(asset)
        touchStory(storyId)
    }

    func addImageAsset(to storyId: UUID, fileUrl: String, name: String? = nil) {
        let existing = assets(for: storyId)
        let asset = StoryAsset(
            storyId: storyId,
            assetType: .image,
            name: name,
            fileUrl: fileUrl,
            displayOrder: existing.count
        )
        storyAssetsMap[storyId, default: []].append(asset)
        touchStory(storyId)
    }

    func updateAsset(_ asset: StoryAsset, name: String?, text: String) {
        guard let assets = storyAssetsMap[asset.storyId],
              let index = assets.firstIndex(where: { $0.id == asset.id })
        else { return }
        storyAssetsMap[asset.storyId]?[index].name = name
        storyAssetsMap[asset.storyId]?[index].contentText = text
        touchStory(asset.storyId)
        // TODO: Update name + content_text in Supabase story_assets table
    }

    func deleteAsset(_ asset: StoryAsset) {
        storyAssetsMap[asset.storyId]?.removeAll { $0.id == asset.id }
        // Reindex display orders
        if var assets = storyAssetsMap[asset.storyId] {
            assets.sort { $0.displayOrder < $1.displayOrder }
            for i in assets.indices {
                assets[i].displayOrder = i
            }
            storyAssetsMap[asset.storyId] = assets
        }
        touchStory(asset.storyId)
    }

    func moveAsset(in storyId: UUID, from source: IndexSet, to destination: Int) {
        var assets = self.assets(for: storyId)
        assets.move(fromOffsets: source, toOffset: destination)
        for i in assets.indices {
            assets[i].displayOrder = i
        }
        storyAssetsMap[storyId] = assets
        touchStory(storyId)
    }

    /// Persists the current display_order for all assets in a story
    /// to Supabase in a single batch update.
    func saveAssetOrder(for storyId: UUID) async {
        let ordered = assets(for: storyId)
        // TODO: Batch update display_order on story_assets in Supabase
        // for asset in ordered {
        //     update story_assets set display_order = asset.displayOrder where id = asset.id
        // }
        _ = ordered
    }

    // MARK: - References

    func references(for storyId: UUID) -> [StoryReference] {
        (storyReferencesMap[storyId] ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    func addReference(to storyId: UUID, videoId: UUID, tag: String) {
        let existing = references(for: storyId)
        let reference = StoryReference(
            storyId: storyId,
            inspirationVideoId: videoId,
            referenceTag: tag,
            aiRelevanceNote: nil,
            displayOrder: existing.count
        )
        storyReferencesMap[storyId, default: []].append(reference)
        touchStory(storyId)
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
                touchStory(storyId)
            }
        }
    }

    func deleteReference(_ reference: StoryReference) {
        storyReferencesMap[reference.storyId]?.removeAll { $0.id == reference.id }
        // Reindex display orders
        if var refs = storyReferencesMap[reference.storyId] {
            refs.sort { $0.displayOrder < $1.displayOrder }
            for i in refs.indices {
                refs[i].displayOrder = i
            }
            storyReferencesMap[reference.storyId] = refs
        }
        touchStory(reference.storyId)
    }

    func moveReference(in storyId: UUID, from source: IndexSet, to destination: Int) {
        var refs = references(for: storyId)
        refs.move(fromOffsets: source, toOffset: destination)
        for i in refs.indices {
            refs[i].displayOrder = i
        }
        storyReferencesMap[storyId] = refs
        touchStory(storyId)
    }

    // MARK: - Asset Sections

    func sections(for storyId: UUID) -> [AssetSection] {
        (storySectionsMap[storyId] ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    func addSection(to storyId: UUID, name: String) {
        let existing = sections(for: storyId)
        let section = AssetSection(
            storyId: storyId,
            name: name,
            displayOrder: existing.count
        )
        storySectionsMap[storyId, default: []].append(section)
        touchStory(storyId)
    }

    func renameSection(_ section: AssetSection, to name: String) {
        guard var sections = storySectionsMap[section.storyId],
              let index = sections.firstIndex(where: { $0.id == section.id })
        else { return }
        sections[index].name = name
        storySectionsMap[section.storyId] = sections
        touchStory(section.storyId)
    }

    /// Deleting a section does NOT delete its assets — they become unsectioned.
    func deleteSection(_ section: AssetSection) {
        // Unfile all assets that belonged to this section
        if var assets = storyAssetsMap[section.storyId] {
            for i in assets.indices where assets[i].sectionId == section.id {
                assets[i].sectionId = nil
            }
            storyAssetsMap[section.storyId] = assets
        }

        storySectionsMap[section.storyId]?.removeAll { $0.id == section.id }

        // Reindex section display orders
        if var sections = storySectionsMap[section.storyId] {
            sections.sort { $0.displayOrder < $1.displayOrder }
            for i in sections.indices {
                sections[i].displayOrder = i
            }
            storySectionsMap[section.storyId] = sections
        }

        touchStory(section.storyId)
    }

    // MARK: - Story Notes

    /// Returns notes for a story, sorted oldest first (chat order).
    func notes(for storyId: UUID) -> [StoryNote] {
        (storyNotesMap[storyId] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    func addNote(to storyId: UUID, text: String, authorName: String = "You") {
        let note = StoryNote(storyId: storyId, authorName: authorName, text: text)
        storyNotesMap[storyId, default: []].append(note)
        touchStory(storyId)
    }

    func updateNote(id noteId: UUID, storyId: UUID, newText: String) {
        guard var notes = storyNotesMap[storyId],
              let index = notes.firstIndex(where: { $0.id == noteId })
        else { return }
        notes[index].text = newText
        storyNotesMap[storyId] = notes
        touchStory(storyId)
    }

    // MARK: - Story Folders

    func createFolder(name: String) {
        let folder = StoryFolder(name: name)
        folders.append(folder)
    }

    func renameFolder(_ folder: StoryFolder, to name: String) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].name = name
    }

    func deleteFolder(_ folder: StoryFolder) {
        // Unfile all stories in this folder — don't delete them
        for (storyId, folderId) in storyFolderMap where folderId == folder.id {
            storyFolderMap.removeValue(forKey: storyId)
        }
        folders.removeAll { $0.id == folder.id }
    }

    func moveStory(_ storyId: UUID, to folderId: UUID?) {
        if let folderId {
            storyFolderMap[storyId] = folderId
        } else {
            storyFolderMap.removeValue(forKey: storyId)
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
    private func touchStory(_ storyId: UUID) {
        guard let index = stories.firstIndex(where: { $0.id == storyId }) else { return }
        stories[index].updatedAt = Date()
    }
}
