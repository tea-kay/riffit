import Foundation

/// A folder for organizing ideas in the library.
/// Will map to a Supabase table later.
struct IdeaFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
