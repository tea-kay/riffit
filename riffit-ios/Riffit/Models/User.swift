import Foundation

/// Represents an authenticated Riffit user.
/// Maps to the `users` table in Supabase.
struct RiffitUser: Codable, Identifiable {
    let id: UUID
    let email: String
    let fullName: String?
    let avatarUrl: String?
    let subscriptionTier: SubscriptionTier
    let onboardingComplete: Bool
    let createdAt: Date

    enum SubscriptionTier: String, Codable {
        case free
        case pro
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case subscriptionTier = "subscription_tier"
        case onboardingComplete = "onboarding_complete"
        case createdAt = "created_at"
    }
}
