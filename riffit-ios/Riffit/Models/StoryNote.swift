import Foundation

/// A note attached to a Story.
/// Same pattern as IdeaComment but scoped to stories.
/// Will map to a Supabase table when persistence is added.
struct StoryNote: Identifiable, Codable, Hashable {
    let id: UUID
    let storyId: UUID
    let authorName: String
    var text: String
    let createdAt: Date

    init(storyId: UUID, authorName: String = "You", text: String) {
        self.id = UUID()
        self.storyId = storyId
        self.authorName = authorName
        self.text = text
        self.createdAt = Date()
    }
}
