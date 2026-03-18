import SwiftUI

/// The main tab bar with 3 tabs shown after onboarding is complete.
/// No tab bar is shown during onboarding — this view only appears
/// once AppState.isOnboardingComplete is true.
///
/// LibraryViewModel is created here and injected as an EnvironmentObject
/// so that both the Library tab and the Storybank's reference picker
/// can share the same video data.
struct MainTabView: View {
    @State private var selectedTab: Tab = .library
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var storybankViewModel = StorybankViewModel()

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
    }
}
