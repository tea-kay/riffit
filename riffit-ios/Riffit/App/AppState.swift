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

                // After the first event we know whether a session exists
                if self.isLoading {
                    self.isLoading = false
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
        do {
            let user: RiffitUser = try await supabase
                .from("users")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value

            self.currentUser = user
            // Sync the onboarding-derived creator profile if available
            // (will be fetched separately when creator_profiles table is wired)
        } catch {
            // Row may not exist yet — treat as unauthenticated for now.
            // A future session event will retry when the row is ready.
            print("[AppState] Failed to fetch user: \(error)")
            self.currentUser = nil
        }
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
