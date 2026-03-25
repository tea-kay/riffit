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
/// - Authenticated → MainTabView
/// Note: Onboarding is bypassed for MVP v1. Re-enable when Phase 2 is built.
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLoading {
                ProgressView()
                    .tint(Color.riffitPrimary)
                    .onAppear { print("[RootView] 🔄 Showing: ProgressView (isLoading=true)") }
            } else if !appState.isAuthenticated {
                AuthView()
                    .onAppear { print("[RootView] 🔒 Showing: AuthView (isAuthenticated=false, currentUser=\(appState.currentUser?.email ?? "nil"))") }
            } else {
                MainTabView()
                    .onAppear { print("[RootView] ✅ Showing: MainTabView") }
            }
        }
    }
}
