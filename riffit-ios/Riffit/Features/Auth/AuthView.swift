import SwiftUI
import AuthenticationServices

/// The sign-in screen shown when the user is not authenticated.
/// Displays the Riffit wordmark, tagline, and Sign in with Apple button.
/// After successful auth, checks onboarding_complete to route
/// to either OnboardingView or MainTabView.
struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            let wordmarkFontSize = max(72, geo.size.width * 0.18)

            ZStack {
                Color.riffitBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Wordmark + tagline centered in upper 60%
                    VStack(spacing: RS.xl) {
                        RiffitWordmark(fontSize: wordmarkFontSize)
                            .frame(
                                width: geo.size.width - 80,
                                height: wordmarkFontSize * 1.4
                            )

                        Text("scroll, riff, post")
                            .font(RF.body(13, weight: .light))
                            .tracking(4)
                            .foregroundStyle(Color.riffitTeal400)
                    }
                    .frame(height: geo.size.height * 0.6)

                    Spacer()

                    // Sign in button + legal text pinned to bottom
                    bottomSection
                }
                .padding(.bottom, 48)

                // Error overlay
                if let error = viewModel.error {
                    errorBanner(error)
                }
            }
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: RS.md) {
            // Apple Sign In button
            SignInWithAppleButton(
                .continue,
                onRequest: { request in
                    viewModel.configureAppleSignIn(request: request)
                },
                onCompletion: { result in
                    Task {
                        await viewModel.handleAppleSignIn(result: result, appState: appState)
                    }
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .cornerRadius(RR.button)

            // Debug-only bypass for simulator testing
            #if DEBUG
            Button {
                // Inject a fake RiffitUser so the app routes past auth + onboarding
                appState.currentUser = RiffitUser(
                    id: UUID(),
                    email: "test@riffit.com",
                    fullName: "Test User",
                    avatarUrl: nil,
                    subscriptionTier: .free,
                    onboardingComplete: true,
                    createdAt: Date()
                )
                appState.isLoading = false
            } label: {
                Text("Continue as Test User")
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextSecondary)
            }
            #endif

            // Terms and privacy caption
            Text("By continuing, you agree to the [Terms of Service](https://riffit.com/terms) and [Privacy Policy](https://riffit.com/privacy).")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextTertiary)
                .multilineTextAlignment(.center)
                .tint(Color.riffitTextTertiary)
        }
        .padding(.horizontal, RS.lg)
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: Error) -> some View {
        VStack {
            HStack(spacing: RS.sm) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Color.riffitDanger)
                Text(error.localizedDescription)
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextPrimary)
                Spacer()
                Button {
                    viewModel.error = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(Color.riffitTextSecondary)
                }
            }
            .padding(RS.smPlus)
            .background(Color.riffitDangerTint)
            .cornerRadius(RR.button)
            .padding(.horizontal, RS.md)

            Spacer()
        }
        .padding(.top, RS.xl2)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeOut(duration: 0.3), value: viewModel.error != nil)
    }
}
