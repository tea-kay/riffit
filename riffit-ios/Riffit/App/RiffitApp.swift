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
            // Main content underneath — always rendered so it's ready when splash fades
            Group {
                if !appState.isAuthenticated && !appState.isLoading {
                    AuthView()
                        .onAppear { print("[RootView] 🔒 Showing: AuthView") }
                } else {
                    MainTabView()
                        .onAppear {
                            print("[RootView] ✅ Showing: MainTabView")
                            appState.checkPendingInviteAfterAuth()
                        }
                }
            }

            // Wave splash screen — covers everything while app initializes.
            // Fades out with 0.4s easeInOut when isLoading becomes false.
            if appState.isLoading || splashVisible {
                WaveSplashView(isLoading: $appState.isLoading)
                    .zIndex(2)
                    .onAppear { print("[RootView] 🌊 Showing: WaveSplashView") }
            }

            // CollabJoinView overlay — shown when a deep link invite is being resolved.
            if appState.showCollabJoinView {
                CollabJoinView()
                    .transition(.opacity)
                    .zIndex(3)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.showCollabJoinView)
        .onChange(of: appState.isLoading) { _, newValue in
            if !newValue {
                // Keep splash in the view tree briefly so the fade-out animation plays,
                // then remove it after the animation completes.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    splashVisible = false
                }
            }
        }
    }

    /// Tracks whether the splash is still in the view tree for fade-out animation.
    @State private var splashVisible: Bool = true
}
