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
            if !appState.isAuthenticated {
                AuthView()
            } else if !appState.isOnboardingComplete {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
    }
}
