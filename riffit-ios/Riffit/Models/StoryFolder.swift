import Foundation

/// A folder for organizing stories in the Storybank.
/// Maps to the `story_folders` table in Supabase.
struct StoryFolder: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID?
    var name: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case createdAt = "created_at"
    }

    init(id: UUID = UUID(), userId: UUID? = nil, name: String, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.name = name
        self.createdAt = createdAt
    }
}
