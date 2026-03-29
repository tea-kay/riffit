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
            // Main content — three-way branch ensures MainTabView only
            // renders AFTER auth is resolved and currentUser is set.
            // This eliminates the race where .task fires with nil userId.
            Group {
                if appState.isLoading {
                    // Splash covers this — nothing to render yet
                    Color.clear
                        .onAppear { print("[RootView] ⏳ Showing: Loading (splash covers)") }
                } else if appState.isAuthenticated {
                    MainTabView()
                        .onAppear {
                            print("[RootView] ✅ Showing: MainTabView")
                            appState.checkPendingInviteAfterAuth()
                        }
                } else {
                    AuthView()
                        .onAppear { print("[RootView] 🔒 Showing: AuthView") }
                }
            }

            // Wave splash screen — covers everything while data is ready.
            // Gates on dataReady (not isLoading) so the splash stays up
            // until at least one tab's data has loaded and is painted.
            if !appState.dataReady || splashVisible {
                WaveSplashView(isLoading: .constant(!appState.dataReady))
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
        .onChange(of: appState.dataReady) { _, ready in
            if ready {
                // Keep splash in the view tree briefly so the fade-out animation plays,
                // then remove it after the animation completes.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    splashVisible = false
                }
            }
        }
        // Safety timeout: if dataReady hasn't fired after 5 seconds
        // (e.g. network failure), fade the splash anyway so the user
        // isn't stuck on an infinite loading screen.
        .task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            appState.markDataReady()
        }
    }

    /// Tracks whether the splash is still in the view tree for fade-out animation.
    @State private var splashVisible: Bool = true
}
