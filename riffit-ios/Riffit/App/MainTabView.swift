import SwiftUI

/// The main tab bar with 4 tabs shown after onboarding is complete.
/// No tab bar is shown during onboarding — this view only appears
/// once AppState.isOnboardingComplete is true.
struct MainTabView: View {
    @State private var selectedTab: Tab = .library

    enum Tab: String {
        case library
        case briefs
        case storybank
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label("Library", systemImage: "house")
            }
            .tag(Tab.library)

            NavigationStack {
                BriefView()
            }
            .tabItem {
                Label("Briefs", systemImage: "doc.text")
            }
            .tag(Tab.briefs)

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
    }
}
