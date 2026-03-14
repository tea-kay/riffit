import SwiftUI

/// The settings tab — profile info, subscription management,
/// connected social accounts, and app preferences.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: .smPlus) {
                    // Appearance
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        settingsRow(
                            icon: appState.appearanceMode.icon,
                            title: "Appearance",
                            detail: appState.appearanceMode.label
                        )
                    }
                    .buttonStyle(.plain)

                    // Placeholder rows for future settings
                    settingsRow(icon: "person.crop.circle", title: "Account", detail: nil)
                    settingsRow(icon: "creditcard", title: "Subscription", detail: nil)
                }
                .padding(.horizontal, .md)
                .padding(.vertical, .smPlus)
            }
        }
        .navigationTitle("Settings")
    }

    // MARK: - Settings Row

    private func settingsRow(icon: String, title: String, detail: String?) -> some View {
        HStack(spacing: .smPlus) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.riffitPrimary)
                .frame(width: 28, height: 28)

            Text(title)
                .riffitBody()
                .foregroundStyle(Color.riffitTextPrimary)

            Spacer()

            if let detail {
                Text(detail)
                    .riffitCaption()
                    .foregroundStyle(Color.riffitTextTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .padding(.md)
        .background(Color.riffitSurface)
        .cornerRadius(.inputRadius)
        .overlay(
            RoundedRectangle(cornerRadius: .inputRadius)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - Appearance Settings

/// Lets the user choose between System, Light, and Dark appearance.
struct AppearanceSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            VStack(spacing: .smPlus) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.appearanceMode = mode
                        }
                    } label: {
                        HStack(spacing: .smPlus) {
                            Image(systemName: mode.icon)
                                .font(.body)
                                .foregroundStyle(Color.riffitPrimary)
                                .frame(width: 28, height: 28)

                            Text(mode.label)
                                .riffitBody()
                                .foregroundStyle(Color.riffitTextPrimary)

                            Spacer()

                            if appState.appearanceMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.riffitPrimary)
                            }
                        }
                        .padding(.md)
                        .background(Color.riffitSurface)
                        .cornerRadius(.inputRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: .inputRadius)
                                .stroke(
                                    appState.appearanceMode == mode
                                        ? Color.riffitPrimary
                                        : Color.riffitBorderSubtle,
                                    lineWidth: appState.appearanceMode == mode ? 1.5 : 0.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, .md)
            .padding(.vertical, .smPlus)
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
