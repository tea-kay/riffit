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
                    VStack(spacing: .xl) {
                        RiffitWordmark(fontSize: wordmarkFontSize)
                            .frame(
                                width: geo.size.width - 80,
                                height: wordmarkFontSize * 1.4
                            )

                        Text("scroll, riff, post")
                            .font(.riffitSans(13, weight: .light))
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
        VStack(spacing: .md) {
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
            .cornerRadius(.buttonRadius)

            // Debug-only bypass for simulator testing
            #if DEBUG
            Button {
                appState.currentUserId = UUID()
                appState.isAuthenticated = true
                appState.isOnboardingComplete = true
            } label: {
                Text("Continue as Test User")
                    .riffitCallout()
                    .foregroundStyle(Color.riffitTextSecondary)
            }
            #endif

            // Terms and privacy caption
            Text("By continuing, you agree to the [Terms of Service](https://riffit.com/terms) and [Privacy Policy](https://riffit.com/privacy).")
                .riffitCaption()
                .foregroundStyle(Color.riffitTextTertiary)
                .multilineTextAlignment(.center)
                .tint(Color.riffitTextTertiary)
        }
        .padding(.horizontal, .lg)
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: Error) -> some View {
        VStack {
            HStack(spacing: .sm) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Color.riffitDanger)
                Text(error.localizedDescription)
                    .riffitCaption()
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
            .padding(.smPlus)
            .background(Color.riffitDangerTint)
            .cornerRadius(.buttonRadius)
            .padding(.horizontal, .md)

            Spacer()
        }
        .padding(.top, .xl2)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeOut(duration: 0.3), value: viewModel.error != nil)
    }
}
