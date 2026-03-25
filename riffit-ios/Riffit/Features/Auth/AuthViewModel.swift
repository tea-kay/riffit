import SwiftUI
import AuthenticationServices
import CryptoKit

/// Handles Sign in with Apple authentication.
/// On success, checks the user's onboarding_complete flag
/// and updates AppState so the app routes correctly.
///
/// Flow:
/// 1. User taps "Continue with Apple"
/// 2. ASAuthorizationAppleIDButton presents the system sheet
/// 3. Apple returns an identity token + authorization code
/// 4. We send these to Supabase Auth to create/sign in the user
/// 5. We fetch the user record to check onboarding_complete
/// 6. AppState is updated → RootView navigates accordingly
@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var error: Error?

    /// A random nonce used for Apple Sign In security.
    /// Generated fresh for each sign-in attempt.
    private var currentNonce: String?

    // MARK: - Configure Request

    /// Called by SignInWithAppleButton's onRequest closure.
    /// Sets up the scopes and nonce for the Apple ID request.
    func configureAppleSignIn(request: ASAuthorizationAppleIDRequest) {
        // Generate a cryptographically secure nonce
        let nonce = generateNonce()
        currentNonce = nonce

        request.requestedScopes = [.fullName, .email]
        // Hash the nonce with SHA256 before sending to Apple
        request.nonce = sha256(nonce)
    }

    // MARK: - Handle Result

    /// Called by SignInWithAppleButton's onCompletion closure.
    /// Processes the Apple Sign In result and authenticates with Supabase.
    func handleAppleSignIn(result: Result<ASAuthorization, Error>, appState: AppState) async {
        switch result {
        case .success(let authorization):
            await processAuthorization(authorization, appState: appState)

        case .failure(let error):
            // ASAuthorizationError.canceled means the user dismissed the sheet — not an error
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled {
                return
            }
            self.error = error
        }
    }

    // MARK: - Process Authorization

    /// Extracts the identity token from Apple's authorization response
    /// and sends it to Supabase Auth for session creation.
    private func processAuthorization(_ authorization: ASAuthorization, appState: AppState) async {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            self.error = AuthError.invalidCredential
            return
        }

        guard let identityTokenData = appleCredential.identityToken,
              let _ = String(data: identityTokenData, encoding: .utf8) else {
            self.error = AuthError.missingIdentityToken
            return
        }

        isLoading = true

        // TODO: Send identity token to Supabase Auth
        // let session = try await supabase.auth.signInWithIdToken(
        //     credentials: .init(
        //         provider: .apple,
        //         idToken: identityToken,
        //         nonce: currentNonce
        //     )
        // )
        //
        // let userId = session.user.id

        // TODO: Fetch the user record to check onboarding_complete
        // let user = try await supabase
        //     .from("users")
        //     .select()
        //     .eq("id", userId)
        //     .single()
        //     .execute()
        //     .value as RiffitUser

        // TODO: Uncomment when Supabase Auth is fully wired:
        // let session = try await supabase.auth.signInWithIdToken(...)
        // The auth state listener in AppState will handle the rest —
        // it will detect the new session, fetch the user row, and
        // set currentUser automatically.

        // Placeholder: simulate successful auth with a fake user
        appState.currentUser = RiffitUser(
            id: UUID(),
            email: "placeholder@riffit.com",
            fullName: "New User",
            username: nil,
            avatarUrl: nil,
            subscriptionTier: .free,
            onboardingComplete: false,
            createdAt: Date()
        )
        appState.isLoading = false

        isLoading = false
    }

    // MARK: - Nonce Generation

    /// Generates a random string used as a nonce for Apple Sign In.
    /// The nonce is sent hashed to Apple and in plaintext to Supabase,
    /// which verifies the identity token was intended for us.
    private func generateNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            // Generate 16 random bytes at a time
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    // Fallback — extremely unlikely to fail
                    random = UInt8.random(in: 0...255)
                }
                return random
            }

            for random in randoms {
                if remainingLength == 0 { break }
                // Map the random byte to a character in the charset
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    /// Hashes a string with SHA256 and returns the hex-encoded result.
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Auth Errors

/// Custom errors for the authentication flow.
enum AuthError: LocalizedError {
    case invalidCredential
    case missingIdentityToken

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Unable to process Apple Sign In credentials."
        case .missingIdentityToken:
            return "Apple Sign In did not return an identity token."
        }
    }
}
