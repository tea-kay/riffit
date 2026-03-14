import SwiftUI

/// The main entry point for the Riffit app.
/// Sets up the root view and injects environment objects
/// (like RiffitColors) that the entire app relies on.
@main
struct RiffitApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

/// Temporary root view — will be replaced with proper
/// navigation (tab bar vs onboarding) once auth is built.
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Text("Riffit")
            .font(.largeTitle)
            .fontWeight(.medium)
    }
}
