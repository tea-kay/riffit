import SwiftUI

/// Global app state that tracks authentication status and
/// whether the user has completed onboarding.
/// Injected as an @EnvironmentObject at the app root.
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isOnboardingComplete: Bool = false
    @Published var currentUserId: UUID?
    @Published var creatorProfileId: UUID?

    /// Called when onboarding finishes successfully.
    /// Updates state so the app transitions from the onboarding
    /// flow to the main tab bar.
    func completeOnboarding(creatorProfileId: UUID) {
        self.creatorProfileId = creatorProfileId
        self.isOnboardingComplete = true
    }
}
