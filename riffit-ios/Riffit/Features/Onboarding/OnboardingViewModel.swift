import SwiftUI

/// Manages onboarding state: creator type selection, AI interview
/// conversation, and CreatorProfile creation on completion.
@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // TODO: Implement onboarding logic (Phase 2)
}
