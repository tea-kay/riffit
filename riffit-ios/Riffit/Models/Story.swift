import Foundation

/// A creative workspace entry in the Storybank.
/// Stories organize assets (voice notes, video, images, text) and
/// references to inspiration videos from the Library.
/// Maps to the `stories` table in Supabase.
struct Story: Codable, Identifiable, Hashable {
    let id: UUID
    let creatorProfileId: UUID
    var title: String
    var status: Status
    let createdAt: Date
    var updatedAt: Date

    enum Status: String, Codable, CaseIterable {
        case draft
        case ready
        case archived
    }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorProfileId = "creator_profile_id"
        case title
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(),
        creatorProfileId: UUID,
        title: String,
        status: Status = .draft,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.creatorProfileId = creatorProfileId
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
