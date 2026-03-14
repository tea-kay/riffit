import SwiftUI

/// Manages the Storybank: stories, their assets, and references.
@MainActor
class StorybankViewModel: ObservableObject {
    @Published var stories: [Story] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    /// Maps story ID → assets, ordered by displayOrder.
    @Published var storyAssetsMap: [UUID: [StoryAsset]] = [:]

    /// Maps story ID → references.
    @Published var storyReferencesMap: [UUID: [StoryReference]] = [:]

    var isEmpty: Bool { stories.isEmpty }

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
        stories.removeAll { $0.id == story.id }
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

    func addVoiceAsset(to storyId: UUID, fileUrl: String, durationSeconds: Int) {
        let existing = assets(for: storyId)
        let asset = StoryAsset(
            storyId: storyId,
            assetType: .voiceNote,
            fileUrl: fileUrl,
            durationSeconds: durationSeconds,
            displayOrder: existing.count
        )
        storyAssetsMap[storyId, default: []].append(asset)
        touchStory(storyId)
    }

    func addVideoAsset(to storyId: UUID, fileUrl: String, durationSeconds: Int?) {
        let existing = assets(for: storyId)
        let asset = StoryAsset(
            storyId: storyId,
            assetType: .video,
            fileUrl: fileUrl,
            durationSeconds: durationSeconds,
            displayOrder: existing.count
        )
        storyAssetsMap[storyId, default: []].append(asset)
        touchStory(storyId)
    }

    func addImageAsset(to storyId: UUID, fileUrl: String) {
        let existing = assets(for: storyId)
        let asset = StoryAsset(
            storyId: storyId,
            assetType: .image,
            fileUrl: fileUrl,
            displayOrder: existing.count
        )
        storyAssetsMap[storyId, default: []].append(asset)
        touchStory(storyId)
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

    // MARK: - References

    func references(for storyId: UUID) -> [StoryReference] {
        (storyReferencesMap[storyId] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    func addReference(to storyId: UUID, videoId: UUID, tag: String) {
        let reference = StoryReference(
            storyId: storyId,
            inspirationVideoId: videoId,
            referenceTag: tag,
            // TODO: Call Edge Function to generate AI relevance note
            aiRelevanceNote: nil
        )
        storyReferencesMap[storyId, default: []].append(reference)
        touchStory(storyId)
    }

    func deleteReference(_ reference: StoryReference) {
        storyReferencesMap[reference.storyId]?.removeAll { $0.id == reference.id }
        touchStory(reference.storyId)
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
