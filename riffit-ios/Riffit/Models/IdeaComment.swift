import Foundation

/// A comment attached to an InspirationVideo.
/// Behaves like a chat message in a thread — the initial userNote
/// from capture becomes the first comment, and users can keep adding thoughts.
/// Will map to a Supabase table when persistence is added.
struct IdeaComment: Identifiable, Codable, Hashable {
    let id: UUID
    let inspirationVideoId: UUID
    let authorName: String   // "You" for now, real names when shared folders land
    let text: String
    let createdAt: Date

    init(inspirationVideoId: UUID, authorName: String = "You", text: String) {
        self.id = UUID()
        self.inspirationVideoId = inspirationVideoId
        self.authorName = authorName
        self.text = text
        self.createdAt = Date()
    }
}
