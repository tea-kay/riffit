import Foundation

/// Represents an authenticated Riffit user.
/// Maps to the `users` table in Supabase.
struct RiffitUser: Codable, Identifiable {
    let id: UUID
    let email: String
    let fullName: String?
    let username: String?
    let avatarUrl: String?
    let subscriptionTier: SubscriptionTier
    let onboardingComplete: Bool
    /// The user ID of whoever referred this user (via invite link or referral link).
    /// First referrer wins — once set, this is never overwritten.
    let referredBy: UUID?
    let createdAt: Date

    enum SubscriptionTier: String, Codable {
        case free
        case pro
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case username
        case avatarUrl = "avatar_url"
        case subscriptionTier = "subscription_tier"
        case onboardingComplete = "onboarding_complete"
        case referredBy = "referred_by"
        case createdAt = "created_at"
    }

    /// Custom decoder that provides sensible defaults for nullable Supabase columns.
    /// email → "" if null, subscriptionTier → .free if null/unknown,
    /// onboardingComplete → false if null, createdAt → Date() if null.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        subscriptionTier = try container.decodeIfPresent(SubscriptionTier.self, forKey: .subscriptionTier) ?? .free
        onboardingComplete = try container.decodeIfPresent(Bool.self, forKey: .onboardingComplete) ?? false
        referredBy = try container.decodeIfPresent(UUID.self, forKey: .referredBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    /// Memberwise init for constructing RiffitUser in Swift code (test users, placeholders).
    init(
        id: UUID,
        email: String,
        fullName: String? = nil,
        username: String? = nil,
        avatarUrl: String? = nil,
        subscriptionTier: SubscriptionTier = .free,
        onboardingComplete: Bool = false,
        referredBy: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.username = username
        self.avatarUrl = avatarUrl
        self.subscriptionTier = subscriptionTier
        self.onboardingComplete = onboardingComplete
        self.referredBy = referredBy
        self.createdAt = createdAt
    }
}
