import Foundation

/// A shareable invite link for a Story.
/// Maps to the `story_invite_links` table in Supabase.
/// The link format is: riffit.app/invite/{token}
/// The token is a short random string stored in this record.
/// When a new user signs up through the link, `referralUserId` (the story owner)
/// gets credited as their referrer for Earn commissions.
struct StoryInviteLink: Identifiable, Codable, Hashable {
    let id: UUID
    let storyId: UUID
    let createdBy: UUID
    /// The role assigned to anyone who joins through this link.
    /// Defaults to `.collaborator` for Free/Pro tiers.
    var role: CollaboratorRole
    /// The story owner's user ID — set as `referred_by` on new users who sign up via this link.
    let referralUserId: UUID?
    /// Short random token that forms the URL: riffit.app/invite/{token}
    let token: String
    /// When the link expires. Nil means it never expires.
    let expiresAt: Date?
    /// Maximum number of users who can join through this link. Nil means unlimited.
    let maxUses: Int?
    /// How many users have already joined through this link.
    var useCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case storyId = "story_id"
        case createdBy = "created_by"
        case role
        case referralUserId = "referral_user_id"
        case token
        case expiresAt = "expires_at"
        case maxUses = "max_uses"
        case useCount = "use_count"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        storyId: UUID,
        createdBy: UUID,
        role: CollaboratorRole = .collaborator,
        referralUserId: UUID? = nil,
        token: String,
        expiresAt: Date? = nil,
        maxUses: Int? = nil,
        useCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.storyId = storyId
        self.createdBy = createdBy
        self.role = role
        self.referralUserId = referralUserId
        self.token = token
        self.expiresAt = expiresAt
        self.maxUses = maxUses
        self.useCount = useCount
        self.createdAt = createdAt
    }

    /// Whether this link can still be used to join.
    var isActive: Bool {
        // Check expiration
        if let expiresAt, Date() > expiresAt {
            return false
        }
        // Check usage limit
        if let maxUses, useCount >= maxUses {
            return false
        }
        return true
    }
}
