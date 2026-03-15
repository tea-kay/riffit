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
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Wordmark + tagline in the upper half
                brandSection

                Spacer()
                Spacer()

                // Sign in button + legal text at the bottom
                bottomSection
            }
            .padding(.horizontal, .lg)
            .padding(.bottom, .xl)

            // Error overlay
            if let error = viewModel.error {
                errorBanner(error)
            }
        }
    }

    // MARK: - Brand Section

    private var brandSection: some View {
        VStack(spacing: .md) {
            Text("Riffit")
                .font(.custom("Georgia-BoldItalic", size: 56))
                .foregroundStyle(Color.riffitPrimaryText)

            Text("scroll, riff, post")
                .riffitTagline()
                .foregroundStyle(Color.riffitTeal400)
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
