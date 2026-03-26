import Foundation

/// A comment attached to an InspirationVideo.
/// Behaves like a chat message in a thread — the initial userNote
/// from capture becomes the first comment, and users can keep adding thoughts.
/// Will map to a Supabase table when persistence is added.
struct IdeaComment: Identifiable, Codable, Hashable {
    let id: UUID
    let inspirationVideoId: UUID
    let userId: UUID?
    let authorName: String
    var text: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case inspirationVideoId = "inspiration_video_id"
        case userId = "user_id"
        case authorName = "author_name"
        case text
        case createdAt = "created_at"
    }

    init(inspirationVideoId: UUID, userId: UUID? = nil, authorName: String = "You", text: String) {
        self.id = UUID()
        self.inspirationVideoId = inspirationVideoId
        self.userId = userId
        self.authorName = authorName
        self.text = text
        self.createdAt = Date()
    }
}
