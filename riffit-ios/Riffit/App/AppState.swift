import SwiftUI

/// Global app state that tracks authentication status and
/// whether the user has completed onboarding.
/// Injected as an @EnvironmentObject at the app root.
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isOnboardingComplete: Bool = false
    @Published var currentUserId: UUID?
    @Published var creatorProfileId: UUID?

    /// User's chosen appearance mode, persisted across launches.
    /// Uses @Published + manual UserDefaults instead of @AppStorage
    /// because @AppStorage inside ObservableObject doesn't fire
    /// objectWillChange, which means .preferredColorScheme() at the
    /// app root never re-evaluates.
    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        self.appearanceMode = AppearanceMode(rawValue: stored) ?? .system
    }

    /// Called when onboarding finishes successfully.
    /// Updates state so the app transitions from the onboarding
    /// flow to the main tab bar.
    func completeOnboarding(creatorProfileId: UUID) {
        self.creatorProfileId = creatorProfileId
        self.isOnboardingComplete = true
    }
}

// MARK: - Appearance Mode

/// Controls whether the app follows system appearance or forces light/dark.
enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// Returns the ColorScheme to force, or nil for system default.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
