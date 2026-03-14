import Foundation

/// The brand brain — everything the AI knows about the creator.
/// Maps to the `creator_profiles` table in Supabase.
struct CreatorProfile: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let creatorType: CreatorType
    let niche: String
    let missionStatement: String
    let targetAudience: String
    let contentPillars: [String]
    let toneMarkers: [String]
    let neverDo: [String]
    let hotTakes: [String]
    let interviewTranscript: [InterviewMessage]?
    let createdAt: Date
    let updatedAt: Date

    enum CreatorType: String, Codable {
        case personalBrand = "personal_brand"
        case educator
        case entertainer
        case business
        case agency
    }

    /// A single message in the AI interview conversation.
    struct InterviewMessage: Codable {
        let role: String   // "user" or "assistant"
        let content: String
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case creatorType = "creator_type"
        case niche
        case missionStatement = "mission_statement"
        case targetAudience = "target_audience"
        case contentPillars = "content_pillars"
        case toneMarkers = "tone_markers"
        case neverDo = "never_do"
        case hotTakes = "hot_takes"
        case interviewTranscript = "interview_transcript"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
