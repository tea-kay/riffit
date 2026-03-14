import SwiftUI

/// Full-screen onboarding flow. No tab bar is shown during this flow.
/// Manages three steps:
/// 1. Creator type selection
/// 2. AI interview conversation
/// 3. Social account connection (optional, skippable)
///
/// Dismissed permanently once the user completes the flow
/// and their CreatorProfile is created.
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            // Background fills the entire screen
            Color.riffitBackground
                .ignoresSafeArea()

            switch viewModel.currentStep {
            case .creatorType:
                CreatorTypeView { selectedType in
                    viewModel.selectCreatorType(selectedType)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

            case .interview:
                interviewStep
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .socialConnect:
                SocialConnectView {
                    completeOnboarding()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
    }

    // MARK: - Interview Step

    /// The interview step with a navigation bar that shows
    /// a "Done" button when the interview is complete.
    private var interviewStep: some View {
        VStack(spacing: 0) {
            // Navigation bar for the interview
            HStack {
                // Back button to go back to creator type selection
                Button {
                    withAnimation {
                        viewModel.currentStep = .creatorType
                    }
                } label: {
                    HStack(spacing: .xs) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .riffitCallout()
                    .foregroundStyle(Color.riffitPrimary)
                }

                Spacer()

                // Show "Continue" when the interview is done
                if viewModel.isInterviewComplete {
                    Button("Continue") {
                        viewModel.finishInterview()
                    }
                    .riffitCallout()
                    .fontWeight(.medium)
                    .foregroundStyle(Color.riffitPrimary)
                }
            }
            .padding(.horizontal, .md)
            .padding(.vertical, .smPlus)

            InterviewView(viewModel: viewModel)
        }
    }

    // MARK: - Complete Onboarding

    /// Finishes the onboarding flow and transitions to the main app.
    private func completeOnboarding() {
        if let profileId = viewModel.finishOnboarding() {
            appState.completeOnboarding(creatorProfileId: profileId)
        }
    }
}

// MARK: - OnboardingStep Equatable

/// Makes OnboardingStep conform to Equatable so SwiftUI's
/// animation(value:) modifier can detect changes.
extension OnboardingViewModel.OnboardingStep: Equatable {}
