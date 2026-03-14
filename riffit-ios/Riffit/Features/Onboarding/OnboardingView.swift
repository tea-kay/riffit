import SwiftUI

/// Full-screen onboarding flow. No tab bar is shown during onboarding.
/// Dismissed permanently once the user completes the AI interview
/// and their CreatorProfile is created.
struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        // TODO: Implement onboarding flow (Phase 2)
        Text("Onboarding")
    }
}
