import Foundation

/// A folder for organizing stories in the Storybank.
/// Will map to a Supabase table later.
struct StoryFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
