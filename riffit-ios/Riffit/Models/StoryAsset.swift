import Foundation

/// A media or text asset attached to a Story.
/// Each story can have multiple assets (voice notes, videos, images, text blocks)
/// that the creator collects while building out their story idea.
/// Maps to the `story_assets` table in Supabase.
struct StoryAsset: Codable, Identifiable, Hashable {
    let id: UUID
    let storyId: UUID
    let assetType: AssetType
    var contentText: String?       // For text assets
    var fileUrl: String?           // For voice/video/image assets
    var durationSeconds: Int?      // For voice/video assets
    var displayOrder: Int
    let createdAt: Date

    enum AssetType: String, Codable, CaseIterable {
        case voiceNote = "voice_note"
        case video
        case image
        case text
    }

    enum CodingKeys: String, CodingKey {
        case id
        case storyId = "story_id"
        case assetType = "asset_type"
        case contentText = "content_text"
        case fileUrl = "file_url"
        case durationSeconds = "duration_seconds"
        case displayOrder = "display_order"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        storyId: UUID,
        assetType: AssetType,
        contentText: String? = nil,
        fileUrl: String? = nil,
        durationSeconds: Int? = nil,
        displayOrder: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.storyId = storyId
        self.assetType = assetType
        self.contentText = contentText
        self.fileUrl = fileUrl
        self.durationSeconds = durationSeconds
        self.displayOrder = displayOrder
        self.createdAt = createdAt
    }
}
