import Foundation

/// A named grouping for assets within a Story.
/// Creators use sections to batch related assets together —
/// e.g. "Hook", "Script", "B-Roll ideas".
/// Maps to the `asset_sections` table in Supabase.
struct AssetSection: Codable, Identifiable, Hashable {
    let id: UUID
    let storyId: UUID
    var name: String
    var displayOrder: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storyId = "story_id"
        case name
        case displayOrder = "display_order"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        storyId: UUID,
        name: String,
        displayOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.storyId = storyId
        self.name = name
        self.displayOrder = displayOrder
        self.createdAt = createdAt
    }
}
