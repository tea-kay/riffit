import Foundation

/// A personal narrative entry in the creator's StoryBank.
/// Used for semantic search when generating content briefs
/// so the AI can reference the creator's real stories.
/// Maps to the `story_entries` table in Supabase.
struct StoryEntry: Codable, Identifiable {
    let id: UUID
    let creatorProfileId: UUID
    let title: String
    let bodyText: String
    let voiceNoteUrl: String?
    let source: Source
    let category: Category
    let tags: [String]
    let createdAt: Date

    enum Source: String, Codable {
        case manual
        case voice
        case aiInterview = "ai_interview"
        case extracted
    }

    enum Category: String, Codable {
        case career
        case win
        case failure
        case opinion
        case background
        case other
    }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorProfileId = "creator_profile_id"
        case title
        case bodyText = "body_text"
        case voiceNoteUrl = "voice_note_url"
        case source
        case category
        case tags
        case createdAt = "created_at"
    }
}
