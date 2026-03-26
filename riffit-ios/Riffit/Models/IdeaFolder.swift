import Foundation

/// A folder for organizing ideas in the library.
/// Will map to a Supabase table later.
struct IdeaFolder: Identifiable, Codable, Hashable {
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
