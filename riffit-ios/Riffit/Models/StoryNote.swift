import Foundation

/// A note attached to a Story.
/// Same pattern as IdeaComment but scoped to stories.
/// Will map to a Supabase table when persistence is added.
struct StoryNote: Identifiable, Codable, Hashable {
    let id: UUID
    let storyId: UUID
    /// The authenticated user who wrote this note — used for RLS and
    /// permission checks (e.g. "can delete others' notes" requires knowing the author).
    let userId: UUID?
    let authorName: String
    var text: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storyId = "story_id"
        case userId = "user_id"
        case authorName = "author_name"
        case text
        case createdAt = "created_at"
    }

    init(storyId: UUID, userId: UUID? = nil, authorName: String = "You", text: String) {
        self.id = UUID()
        self.storyId = storyId
        self.userId = userId
        self.authorName = authorName
        self.text = text
        self.createdAt = Date()
    }
}
