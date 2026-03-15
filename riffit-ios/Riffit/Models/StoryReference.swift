import Foundation

/// A reference linking a Story to an InspirationVideo from the Library.
/// When a creator pulls inspiration from a saved video, this tracks
/// which tag they referenced it for and includes an AI-generated note
/// explaining why it's relevant to the story.
/// Maps to the `story_references` table in Supabase.
struct StoryReference: Codable, Identifiable, Hashable {
    let id: UUID
    let storyId: UUID
    let inspirationVideoId: UUID
    let referenceTag: String       // Hook, Editing, B-Roll, Format, Topic, Inspiration
    var aiRelevanceNote: String?   // AI-generated one-liner about why this is relevant
    var displayOrder: Int          // Position in the references list (for reordering)
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storyId = "story_id"
        case inspirationVideoId = "inspiration_video_id"
        case referenceTag = "reference_tag"
        case aiRelevanceNote = "ai_relevance_note"
        case displayOrder = "display_order"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        storyId: UUID,
        inspirationVideoId: UUID,
        referenceTag: String,
        aiRelevanceNote: String? = nil,
        displayOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.storyId = storyId
        self.inspirationVideoId = inspirationVideoId
        self.referenceTag = referenceTag
        self.aiRelevanceNote = aiRelevanceNote
        self.displayOrder = displayOrder
        self.createdAt = createdAt
    }
}
