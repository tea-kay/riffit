import Foundation

/// A saved video from any supported platform.
/// Maps to the `inspiration_videos` table in Supabase.
struct InspirationVideo: Codable, Identifiable {
    let id: UUID
    let creatorProfileId: UUID
    let url: String
    let platform: Platform
    let userNote: String?
    let thumbnailUrl: String?
    let transcript: String?
    var summary: String?              // AI-generated one-line summary of what the video is about
    let alignmentScore: Int?
    let alignmentVerdict: AlignmentVerdict?
    let alignmentReasoning: String?
    let status: Status
    var viewCount: Int?               // Manually entered video view count
    var likeCount: Int?               // Manually entered video like count
    var commentCount: Int?            // Manually entered video comment count
    let statSource: String?           // "manual" for MVP, "api" in v2 (Phyllo)
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
        case pending
        case analyzing
        case analyzed
        case archived
    }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorProfileId = "creator_profile_id"
        case url
        case platform
        case userNote = "user_note"
        case thumbnailUrl = "thumbnail_url"
        case transcript
        case summary
        case alignmentScore = "alignment_score"
        case alignmentVerdict = "alignment_verdict"
        case alignmentReasoning = "alignment_reasoning"
        case status
        case viewCount = "view_count"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case statSource = "stat_source"
        case savedAt = "saved_at"
    }
}
