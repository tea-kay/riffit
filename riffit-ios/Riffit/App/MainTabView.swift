import SwiftUI

/// The main tab bar with 3 tabs shown after onboarding is complete.
/// No tab bar is shown during onboarding — this view only appears
/// once AppState.isOnboardingComplete is true.
///
/// LibraryViewModel is created here and injected as an EnvironmentObject
/// so that both the Library tab and the Storybank's reference picker
/// can share the same video data.
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .library
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var storybankViewModel = StorybankViewModel()

    /// Gold tab badge color — no SwiftUI equivalent for badge color customization
    init() {
        UITabBarItem.appearance().badgeColor = UIColor(
            red: 240.0 / 255, green: 170.0 / 255, blue: 32.0 / 255, alpha: 1
        )
    }

    enum Tab: String {
        case library
        case storybank
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("Ideas", systemImage: "lightbulb")
            }
            .tag(Tab.library)

            NavigationStack {
                StorybankView()
            }
            .tabItem {
                Label("Storybank", systemImage: "bookmark")
            }
            .tag(Tab.storybank)
            .badge(storybankViewModel.pendingInvites.count)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(Tab.settings)
        }
        .tint(Color.riffitPrimary)
        .environmentObject(libraryViewModel)
        .environmentObject(storybankViewModel)
        // Prefetch both tabs' data, then tell the splash it's safe to fade.
        // Each ViewModel's .task guard on hasLoadedOnce prevents double-fetch.
        .task {
            let userId = appState.currentUser?.id
            async let lib: Void = libraryViewModel.fetchVideos(userId: userId)
            async let sb: Void = storybankViewModel.fetchStories(userId: userId)
            _ = await (lib, sb)
            appState.markDataReady()
        }
    }
}
