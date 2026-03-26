import Foundation

/// A saved video from any supported platform.
/// Maps to the `inspiration_videos` table in Supabase.
struct InspirationVideo: Codable, Identifiable {
    let id: UUID
    let creatorProfileId: UUID
    let url: String
    let platform: Platform
    var title: String?                // From og:title metadata or manual entry
    let userNote: String?
    let thumbnailUrl: String?
    let transcript: String?
    let alignmentScore: Int?
    let alignmentVerdict: AlignmentVerdict?
    let alignmentReasoning: String?
    let status: Status
    let savedAt: Date

    enum Platform: String, Codable, CaseIterable {
        case instagram
        case tiktok
        case youtube
        case linkedin
        case x
    }

    enum AlignmentVerdict: String, Codable {
        case skip
        case consider
        case strong
    }

    enum Status: String, Codable {
        case saved
        case archived
    }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorProfileId = "creator_profile_id"
        case url
        case platform
        case title
        case userNote = "user_note"
        case thumbnailUrl = "thumbnail_url"
        case transcript
        case alignmentScore = "alignment_score"
        case alignmentVerdict = "alignment_verdict"
        case alignmentReasoning = "alignment_reasoning"
        case status
        case savedAt = "created_at"
    }
}
