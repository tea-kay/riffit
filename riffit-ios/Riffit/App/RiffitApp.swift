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
                // Handle universal links (riffit.app/invite/{token})
                // Works for both cold launch and backgrounded app.
                .onOpenURL { url in
                    appState.handleDeepLink(url)
                }
        }
    }
}

/// Root view that decides what to show based on app state:
/// - Not authenticated → AuthView
/// - Authenticated → MainTabView
/// - Pending invite → CollabJoinView overlay
/// Note: Onboarding is bypassed for MVP v1. Re-enable when Phase 2 is built.
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
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
                        .onAppear {
                            print("[RootView] ✅ Showing: MainTabView")
                            // After auth completes, check if there's a pending invite
                            appState.checkPendingInviteAfterAuth()
                        }
                }
            }

            // CollabJoinView overlay — shown when a deep link invite is being resolved.
            // Presented as a full-screen overlay above the current content.
            if appState.showCollabJoinView {
                CollabJoinView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.showCollabJoinView)
    }
}
