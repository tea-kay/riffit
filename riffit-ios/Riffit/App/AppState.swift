import SwiftUI
import Supabase

/// Global app state that tracks authentication status and
/// whether the user has completed onboarding.
/// Injected as an @EnvironmentObject at the app root.
///
/// On launch, listens to Supabase auth state changes via an async stream.
/// When a session arrives, fetches the matching row from public.users
/// and populates currentUser. When signed out, clears it.
@MainActor
class AppState: ObservableObject {
    // MARK: - Auth State

    /// The authenticated Riffit user, fetched from the public.users table.
    /// nil means the user is not signed in.
    @Published var currentUser: RiffitUser?

    /// True while we check for an existing Supabase session on launch.
    /// Views can show a loading state until this becomes false.
    @Published var isLoading: Bool = true

    /// Convenience — true when a user is signed in.
    /// Existing views read this to decide whether to show AuthView.
    var isAuthenticated: Bool {
        currentUser != nil
    }

    /// Convenience — reads the onboarding flag from the user record.
    /// Falls back to false when there is no user.
    var isOnboardingComplete: Bool {
        currentUser?.onboardingComplete ?? false
    }

    /// Convenience — the signed-in user's UUID, or nil.
    var currentUserId: UUID? {
        currentUser?.id
    }

    /// The creator profile associated with the current user.
    /// Set after onboarding completes or when fetched from the DB.
    @Published var creatorProfileId: UUID?

    // MARK: - Deep Link / Invite State

    /// Token from a collaboration invite deep link (riffit.app/invite/{token}).
    /// Stored here so it survives the auth flow — if user isn't signed in,
    /// they sign in first, then the invite is resolved.
    @Published var pendingInviteToken: String?

    /// The story owner's user_id from the invite link record.
    /// Set as `referred_by` on new users who sign up via this link.
    @Published var pendingReferralUserId: UUID?

    /// The resolved invite link data, ready for CollabJoinView to display.
    /// Set after the token is looked up and validated.
    @Published var resolvedInvite: ResolvedInvite?

    /// Whether to show the CollabJoinView overlay.
    @Published var showCollabJoinView: Bool = false

    /// Data needed to display the CollabJoinView after resolving an invite token.
    struct ResolvedInvite {
        let inviteLink: StoryInviteLink
        let storyTitle: String
        let ownerName: String
        let ownerAvatarUrl: String?
        let assetCount: Int
        let referenceCount: Int
    }

    /// Possible states when an invite link can't be used.
    enum InviteError {
        case expired
        case notFound
        case alreadyMember
    }

    /// Set when the invite link is invalid — CollabJoinView shows an error state.
    @Published var inviteError: InviteError?

    /// User's chosen appearance mode, persisted across launches.
    /// Uses @Published + manual UserDefaults instead of @AppStorage
    /// because @AppStorage inside ObservableObject doesn't fire
    /// objectWillChange, which means .preferredColorScheme() at the
    /// app root never re-evaluates.
    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    /// Holds the auth listener task so it lives as long as AppState does.
    private var authListenerTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        let stored = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        self.appearanceMode = AppearanceMode(rawValue: stored) ?? .system

        // TEMPORARY: Verify Supabase connection is live — remove after confirming
        #if DEBUG
        Task { await self.testConnection() }
        #endif

        // Start listening to Supabase auth state changes.
        // This fires immediately with the current session (if any),
        // then again on every sign-in / sign-out / token refresh.
        authListenerTask = Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }

                print("[AppState] 🔔 authStateChanges event: \(event)")
                print("[AppState]    session present: \(session != nil)")
                if let session {
                    print("[AppState]    session user.id: \(session.user.id)")
                    print("[AppState]    session user.email: \(session.user.email ?? "nil")")
                }

                switch event {
                case .initialSession, .signedIn, .tokenRefreshed:
                    if let session {
                        await self.fetchUser(id: session.user.id)
                    } else {
                        // initialSession with no session means no one is logged in
                        self.currentUser = nil
                    }

                case .signedOut:
                    self.currentUser = nil
                    self.creatorProfileId = nil

                default:
                    break
                }

                print("[AppState] 📊 After event — currentUser: \(self.currentUser?.email ?? "nil"), isAuthenticated: \(self.isAuthenticated), isOnboardingComplete: \(self.isOnboardingComplete), isLoading: \(self.isLoading)")

                // After the first event we know whether a session exists
                if self.isLoading {
                    self.isLoading = false
                    print("[AppState]    isLoading set to false")
                }
            }
        }
    }

    deinit {
        authListenerTask?.cancel()
    }

    // MARK: - Fetch User

    /// Fetches the user row from public.users matching the auth UID.
    /// If the row doesn't exist yet (first sign-in before the DB trigger
    /// creates it), currentUser stays nil and isLoading still clears.
    private func fetchUser(id: UUID) async {
        print("[AppState] fetchUser called for id: \(id)")
        do {
            let user: RiffitUser = try await supabase
                .from("users")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value

            print("[AppState] ✅ fetchUser succeeded — email: \(user.email), onboardingComplete: \(user.onboardingComplete)")
            self.currentUser = user
            // Sync the onboarding-derived creator profile if available
            // (will be fetched separately when creator_profiles table is wired)
        } catch {
            // Row may not exist yet — treat as unauthenticated for now.
            // A future session event will retry when the row is ready.
            print("[AppState] ❌ fetchUser FAILED — \(error)")
            self.currentUser = nil
        }
    }

    // MARK: - Profile Updates

    /// Updates the user's full_name in the database and refreshes currentUser.
    func updateFullName(_ name: String) async throws {
        guard let userId = currentUser?.id else { return }
        try await supabase
            .from("users")
            .update(["full_name": name])
            .eq("id", value: userId)
            .execute()
        await fetchUser(id: userId)
    }

    /// Updates the user's username in the database and refreshes currentUser.
    func updateUsername(_ username: String) async throws {
        guard let userId = currentUser?.id else {
            print("[AppState] updateUsername — no currentUser, aborting")
            return
        }
        print("[AppState] updateUsername — saving '\(username)' for user \(userId)")
        do {
            try await supabase
                .from("users")
                .update(["username": username])
                .eq("id", value: userId)
                .execute()
            print("[AppState] updateUsername — saved OK")
            await fetchUser(id: userId)
        } catch {
            print("[AppState] ❌ updateUsername FAILED — \(error)")
            throw error
        }
    }

    /// Uploads an image to Supabase Storage and updates avatar_url on the user row.
    func uploadAvatar(imageData: Data) async throws {
        guard let userId = currentUser?.id else {
            print("[AppState] uploadAvatar — no currentUser, aborting")
            return
        }

        let filePath = "\(userId.uuidString)/avatar.jpg"
        print("[AppState] uploadAvatar — uploading \(imageData.count) bytes to thumbnails/\(filePath)")

        // Upload to the "thumbnails" bucket (public, per CLAUDE.md)
        // Use upsert so re-uploads overwrite the previous avatar
        let uploadResponse = try await supabase.storage
            .from("thumbnails")
            .upload(
                filePath,
                data: imageData,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: true
                )
            )
        print("[AppState] uploadAvatar — storage upload succeeded: \(uploadResponse)")

        // Build the public URL for the uploaded file.
        // Append a cache-busting timestamp so AsyncImage treats re-uploads
        // as a new URL — otherwise it serves the stale cached version.
        let baseUrl = try supabase.storage
            .from("thumbnails")
            .getPublicURL(path: filePath)
        let cacheBustedUrl = "\(baseUrl.absoluteString)?t=\(Int(Date().timeIntervalSince1970))"
        print("[AppState] uploadAvatar — public URL: \(cacheBustedUrl)")

        // Save the URL to the user row
        try await supabase
            .from("users")
            .update(["avatar_url": cacheBustedUrl])
            .eq("id", value: userId)
            .execute()
        print("[AppState] uploadAvatar — users table updated with avatar_url")

        // Re-fetch so currentUser.avatarUrl updates everywhere
        await fetchUser(id: userId)
        print("[AppState] uploadAvatar — currentUser refreshed, avatarUrl: \(currentUser?.avatarUrl ?? "nil")")
    }

    // MARK: - Debug Connection Test (TEMPORARY — remove after verifying)

    #if DEBUG
    /// Runs a simple SELECT from public.users with limit 1 to confirm
    /// the Supabase project URL and anon key are working.
    /// Check the Xcode console for the result.
    private func testConnection() async {
        do {
            let response = try await supabase
                .from("users")
                .select()
                .limit(1)
                .execute()

            let json = String(data: response.data, encoding: .utf8) ?? "(no data)"
            print("[AppState] ✅ Supabase connection OK — response: \(json)")
        } catch {
            print("[AppState] ❌ Supabase connection FAILED — \(error)")
        }
    }
    #endif

    // MARK: - Sign Out

    /// Signs out of Supabase. The auth state listener will react
    /// and clear currentUser automatically.
    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            print("[AppState] Sign out failed: \(error)")
        }
    }

    /// Called when onboarding finishes successfully.
    /// Updates state so the app transitions from the onboarding
    /// flow to the main tab bar.
    func completeOnboarding(creatorProfileId: UUID) {
        self.creatorProfileId = creatorProfileId
        // Re-fetch user so onboardingComplete reflects the DB update
        if let userId = currentUser?.id {
            Task {
                await fetchUser(id: userId)
            }
        }
    }

    // MARK: - Deep Link Handling

    /// Parses a universal link URL and extracts the invite token if it matches
    /// the pattern: riffit.app/invite/{token}
    /// Called from .onOpenURL on the root view.
    func handleDeepLink(_ url: URL) {
        // Accept both riffit.app and any test scheme
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        // Look for /invite/{token} pattern
        guard pathComponents.count >= 2,
              pathComponents[0] == "invite",
              !pathComponents[1].isEmpty
        else {
            print("[AppState] Deep link ignored — not an invite URL: \(url)")
            return
        }

        let token = pathComponents[1]
        print("[AppState] Deep link received — invite token: \(token)")

        pendingInviteToken = token

        // Extract referral user ID from query params if present (?ref=xxx)
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let refParam = components.queryItems?.first(where: { $0.name == "ref" })?.value,
           let refId = UUID(uuidString: refParam) {
            pendingReferralUserId = refId
        }

        // If already signed in, resolve immediately
        if isAuthenticated {
            showCollabJoinView = true
        }
        // If not signed in, token stays in pendingInviteToken.
        // After auth completes, the root view checks and shows CollabJoinView.
    }

    /// Called after an invite is successfully joined or dismissed.
    func clearPendingInvite() {
        pendingInviteToken = nil
        pendingReferralUserId = nil
        resolvedInvite = nil
        inviteError = nil
        showCollabJoinView = false
    }

    /// Called after auth completes to check if there's a pending invite to resolve.
    func checkPendingInviteAfterAuth() {
        if pendingInviteToken != nil {
            showCollabJoinView = true
        }
    }
}

// MARK: - Appearance Mode

/// Controls whether the app follows system appearance or forces light/dark.
enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// Returns the ColorScheme to force, or nil for system default.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
