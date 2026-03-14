import Foundation

/// The structural breakdown of an inspiration video.
/// One-to-one relationship with InspirationVideo.
/// Maps to the `video_deconstructions` table in Supabase.
struct VideoDeconstruction: Codable, Identifiable {
    let id: UUID
    let inspirationVideoId: UUID
    let hookText: String
    let hookType: HookType
    let fullTranscript: String
    let structureSegments: [StructureSegment]
    let brollMoments: [BRollMoment]
    let transitionNotes: String?
    let cutCount: Int
    let pacing: Pacing
    let createdAt: Date

    enum HookType: String, Codable {
        case question
        case stat
        case story
        case boldClaim = "bold_claim"
        case visual
    }

    enum Pacing: String, Codable {
        case slow
        case medium
        case fast
    }

    /// A segment of the video's structure (intro, point, outro, etc.)
    struct StructureSegment: Codable {
        let type: String
        let text: String
        let timingStart: Double?
        let timingEnd: Double?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case timingStart = "timing_start"
            case timingEnd = "timing_end"
        }
    }

    /// A moment in the video suitable for B-roll footage.
    struct BRollMoment: Codable {
        let description: String
        let timing: Double?
        let duration: Double?
    }

    enum CodingKeys: String, CodingKey {
        case id
        case inspirationVideoId = "inspiration_video_id"
        case hookText = "hook_text"
        case hookType = "hook_type"
        case fullTranscript = "full_transcript"
        case structureSegments = "structure_segments"
        case brollMoments = "broll_moments"
        case transitionNotes = "transition_notes"
        case cutCount = "cut_count"
        case pacing
        case createdAt = "created_at"
    }
}
