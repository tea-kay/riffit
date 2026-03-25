import SwiftUI
import AuthenticationServices
import Supabase

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

            // Dev-only email auth for testing before Apple Sign In is configured
            #if DEBUG
            DevEmailSignInSection(appState: appState)
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

// MARK: - Dev Email Sign In (DEBUG only)

#if DEBUG
/// Temporary email/password sign-in form for development.
/// The auth state listener in AppState picks up the session automatically
/// on success — no manual routing needed here.
private struct DevEmailSignInSection: View {
    @ObservedObject var appState: AppState
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: RS.sm) {
            dividerRow

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.emailAddress)
                .font(RF.bodyMd)
                .padding(RS.smPlus)
                .background(Color.riffitElevated)
                .cornerRadius(RR.input)
                .overlay(
                    RoundedRectangle(cornerRadius: RR.input)
                        .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                )

            SecureField("Password", text: $password)
                .textContentType(.password)
                .font(RF.bodyMd)
                .padding(RS.smPlus)
                .background(Color.riffitElevated)
                .cornerRadius(RR.input)
                .overlay(
                    RoundedRectangle(cornerRadius: RR.input)
                        .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                )

            // Sign in — secondary variant
            RiffitButton(title: isLoading ? "Signing in…" : "Sign in with email", variant: .secondary) {
                Task { await signIn() }
            }

            // Create account — ghost variant
            RiffitButton(title: "Create account", variant: .ghost) {
                Task { await signUp() }
            }

            // Offline test user bypass
            Button {
                appState.currentUser = RiffitUser(
                    id: UUID(),
                    email: "test@riffit.com",
                    fullName: "Test User",
                    username: nil,
                    avatarUrl: nil,
                    subscriptionTier: .free,
                    onboardingComplete: true,
                    createdAt: Date()
                )
                appState.isLoading = false
            } label: {
                Text("Continue as Test User (offline)")
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextSecondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitDanger)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Divider

    private var dividerRow: some View {
        HStack(spacing: RS.sm) {
            Rectangle()
                .fill(Color.riffitBorderSubtle)
                .frame(height: 0.5)
            Text("DEV")
                .font(RF.label)
                .foregroundStyle(Color.riffitTextTertiary)
            Rectangle()
                .fill(Color.riffitBorderSubtle)
                .frame(height: 0.5)
        }
    }

    // MARK: - Actions

    private func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter both email and password."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            // AppState's auth listener will detect the new session
            // and fetch the user row automatically
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signUp() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter both email and password."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await supabase.auth.signUp(email: email, password: password)
            // Sign in immediately so a session is created and
            // the auth state listener in AppState navigates the user in
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
