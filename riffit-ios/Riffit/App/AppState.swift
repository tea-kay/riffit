import SwiftUI

/// Global app state that tracks authentication status and
/// whether the user has completed onboarding.
/// Injected as an @EnvironmentObject at the app root.
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isOnboardingComplete: Bool = false
    @Published var currentUserId: UUID?
}
