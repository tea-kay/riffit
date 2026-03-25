import SwiftUI

/// The main entry point for the Riffit app.
/// Sets up the root view and injects the global AppState
/// environment object that the entire app relies on.
@main
struct RiffitApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                // Apply the user's chosen appearance mode.
                // nil means follow the system setting.
                .preferredColorScheme(appState.appearanceMode.colorScheme)
        }
    }
}

/// Root view that decides what to show based on app state:
/// - Not authenticated → AuthView
/// - Authenticated but not onboarded → OnboardingView (full-screen, no tab bar)
/// - Authenticated and onboarded → MainTabView (the main app)
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLoading {
                // Show a minimal loading state while checking for an existing session
                ProgressView()
                    .tint(Color.riffitPrimary)
                    .onAppear { print("[RootView] 🔄 Showing: ProgressView (isLoading=true)") }
            } else if !appState.isAuthenticated {
                AuthView()
                    .onAppear { print("[RootView] 🔒 Showing: AuthView (isAuthenticated=false, currentUser=\(appState.currentUser?.email ?? "nil"))") }
            } else if !appState.isOnboardingComplete {
                OnboardingView()
                    .onAppear { print("[RootView] 📋 Showing: OnboardingView (isOnboardingComplete=false)") }
            } else {
                MainTabView()
                    .onAppear { print("[RootView] ✅ Showing: MainTabView") }
            }
        }
    }
}
