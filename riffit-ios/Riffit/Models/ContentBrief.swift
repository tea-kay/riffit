import Foundation

/// The primary output of Riffit — the creative brief a creator
/// takes into filming. Contains a remixed concept, hook, sections
/// with story references, and a shot list.
/// Maps to the `content_briefs` table in Supabase.
struct ContentBrief: Codable, Identifiable {
    let id: UUID
    let inspirationVideoId: UUID
    let creatorProfileId: UUID
    let remixedConcept: String
    let remixedHook: String
    let sections: [BriefSection]
    let shotList: [Shot]
    let storyRefs: [UUID]
    let userSelections: [String: String]?
    let status: Status
    let createdAt: Date
    let updatedAt: Date

    enum Status: String, Codable {
        case draft
        case active
        case done
        case archived
    }

    /// A section of the content brief with direction and timing.
    struct BriefSection: Codable {
        let number: Int
        let title: String
        let direction: String
        let storyRefId: UUID?
        let timingGuide: String?

        enum CodingKeys: String, CodingKey {
            case number
            case title
            case direction
            case storyRefId = "story_ref_id"
            case timingGuide = "timing_guide"
        }
    }

    /// A single shot in the shot list.
    struct Shot: Codable {
        let shotNumber: Int
        let description: String
        let type: String
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case shotNumber = "shot_number"
            case description
            case type
            case notes
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case inspirationVideoId = "inspiration_video_id"
        case creatorProfileId = "creator_profile_id"
        case remixedConcept = "remixed_concept"
        case remixedHook = "remixed_hook"
        case sections
        case shotList = "shot_list"
        case storyRefs = "story_refs"
        case userSelections = "user_selections"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
