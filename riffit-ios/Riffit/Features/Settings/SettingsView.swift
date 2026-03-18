import SwiftUI

/// The settings tab — account info, plan, creative profile,
/// app preferences, legal, and sign out.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var storybankViewModel: StorybankViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel

    @State private var showComingSoon: Bool = false
    @State private var showSignOutConfirm: Bool = false

    /// Dynamic subtitle for the "Your influences" row
    private var influencesSubtitle: String {
        let allRefs = storybankViewModel.storyReferencesMap.values.flatMap { $0 }
        let grouped = Dictionary(grouping: allRefs, by: \.inspirationVideoId)
        let count = grouped.values.filter { $0.count >= 3 }.count
        return "\(count) video\(count == 1 ? "" : "s") referenced 3+ times"
    }

    /// Bundle version string for the Legal section
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: RS.lg) {
                    // ── Account card (standalone, navigates to AccountView) ──
                    NavigationLink {
                        AccountView()
                    } label: {
                        accountCard
                    }
                    .buttonStyle(.plain)

                    // ── Plan section ──
                    settingsSection("Plan") {
                        NavigationLink {
                            comingSoonPlaceholder
                        } label: {
                            iconRow(
                                icon: "star.fill",
                                iconColor: Color.riffitPrimary,
                                iconBackground: Color.riffitPrimaryTint,
                                title: "Riff Pro",
                                subtitle: "Unlimited saves + AI features",
                                trailing: .badge("Upgrade", color: Color.riffitPrimary)
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            comingSoonPlaceholder
                        } label: {
                            iconRow(
                                icon: "square.grid.2x2",
                                iconColor: Color.riffitTeal400,
                                iconBackground: Color.riffitTealTint,
                                title: "Current usage",
                                subtitle: "12 of 50 saves · 2 of 5 stories"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // ── Creative section ──
                    settingsSection("Creative") {
                        NavigationLink {
                            comingSoonPlaceholder
                        } label: {
                            iconRow(
                                icon: "person.text.rectangle",
                                iconColor: Color.riffitTeal400,
                                iconBackground: Color.riffitTealTint,
                                title: "Creator profile",
                                subtitle: "Niche, tone, content pillars"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            InfluencesView()
                        } label: {
                            iconRow(
                                icon: "sparkles",
                                iconColor: Color.riffitTeal400,
                                iconBackground: Color.riffitTealTint,
                                title: "Your influences",
                                subtitle: influencesSubtitle
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // ── App section ──
                    settingsSection("App") {
                        NavigationLink {
                            AppearanceSettingsView()
                        } label: {
                            iconRow(
                                icon: appState.appearanceMode.icon,
                                iconColor: Color.riffitPrimary,
                                iconBackground: Color.riffitPrimaryTint,
                                title: "Appearance",
                                subtitle: appState.appearanceMode.label
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // ── Legal section ──
                    settingsSection("Legal") {
                        NavigationLink {
                            comingSoonPlaceholder
                        } label: {
                            iconRow(
                                icon: "lock.shield",
                                iconColor: Color.riffitTextSecondary,
                                iconBackground: Color.riffitSurface,
                                title: "Privacy policy"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            comingSoonPlaceholder
                        } label: {
                            iconRow(
                                icon: "doc.text",
                                iconColor: Color.riffitTextSecondary,
                                iconBackground: Color.riffitSurface,
                                title: "Terms of service"
                            )
                        }
                        .buttonStyle(.plain)

                        // Version row — not tappable, no chevron
                        HStack(spacing: RS.smPlus) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(Color.riffitTextSecondary)
                                .frame(width: 28, height: 28)
                                .background(Color.riffitSurface)
                                .cornerRadius(RR.tag)

                            Text("Version")
                                .font(RF.bodyMd)
                                .foregroundStyle(Color.riffitTextPrimary)

                            Spacer()

                            Text(appVersion)
                                .font(RF.caption)
                                .foregroundStyle(Color.riffitTextTertiary)
                        }
                        .padding(RS.md)
                        .background(Color.riffitSurface)
                        .cornerRadius(RR.input)
                        .overlay(
                            RoundedRectangle(cornerRadius: RR.input)
                                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
                        )
                    }

                    // ── Sign out ──
                    RiffitButton(title: "Sign out", variant: .danger) {
                        showSignOutConfirm = true
                    }

                    // Bottom padding so content doesn't crowd the tab bar
                    Color.clear.frame(height: RS.lg)
                }
                .padding(.horizontal, RS.md)
                .padding(.top, RS.smPlus)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(RF.title)
                    .foregroundStyle(Color.riffitTextPrimary)
            }
        }
        .sheet(isPresented: $showComingSoon) {
            comingSoonSheet
        }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign out", role: .destructive) {
                // TODO: Wire to auth signOut
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign back in to access your stories.")
        }
    }

    // MARK: - Account Card

    private var accountCard: some View {
        HStack(spacing: RS.smPlus) {
            // Avatar circle with initial
            Text("T")
                .font(RF.heading)
                .foregroundStyle(Color.riffitTeal400)
                .frame(width: 48, height: 48)
                .background(Color.riffitTealTint)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.riffitTeal400, lineWidth: 1.5)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Timothy")
                    .font(RF.heading)
                    .foregroundStyle(Color.riffitTextPrimary)

                Text("Creator · Free plan")
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextSecondary)
            }

            Spacer()

            // Free badge + chevron
            Text("Free")
                .font(RF.tag)
                .foregroundStyle(Color.riffitPrimary)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.riffitPrimaryTint)
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .contentShape(Rectangle())
        .padding(RS.md)
        .background(Color.riffitSurface)
        .cornerRadius(RR.card)
        .overlay(
            RoundedRectangle(cornerRadius: RR.card)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Section Builder

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            Text(title)
                .font(RF.tag)
                .textCase(.uppercase)
                .tracking(0.06 * 11)
                .foregroundStyle(Color.riffitTextTertiary)

            content()
        }
    }

    // MARK: - Icon Row

    private enum TrailingContent {
        case chevron
        case badge(String, color: Color)
    }

    private func iconRow(
        icon: String,
        iconColor: Color,
        iconBackground: Color,
        title: String,
        subtitle: String? = nil,
        trailing: TrailingContent = .chevron
    ) -> some View {
        HStack(spacing: RS.smPlus) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconBackground)
                .cornerRadius(RR.tag)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(RF.meta)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
            }

            Spacer()

            switch trailing {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.riffitTextTertiary)

            case .badge(let text, let color):
                Text(text)
                    .font(RF.tag)
                    .foregroundStyle(color)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .padding(RS.md)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Placeholders

    private var comingSoonPlaceholder: some View {
        ZStack {
            Color.riffitBackground.ignoresSafeArea()

            Text("Coming soon")
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var comingSoonSheet: some View {
        VStack(spacing: RS.lg) {
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, RS.smPlus)

            Spacer()

            Text("Coming soon")
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)

            Text("This feature is on the way.")
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.riffitBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(RR.modal)
        .presentationBackground(Color.riffitBackground)
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

            VStack(spacing: RS.smPlus) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.appearanceMode = mode
                        }
                    } label: {
                        HStack(spacing: RS.smPlus) {
                            Image(systemName: mode.icon)
                                .font(.body)
                                .foregroundStyle(Color.riffitPrimary)
                                .frame(width: 28, height: 28)

                            Text(mode.label)
                                .font(RF.bodyMd)
                                .foregroundStyle(Color.riffitTextPrimary)

                            Spacer()

                            if appState.appearanceMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.riffitPrimary)
                            }
                        }
                        .padding(RS.md)
                        .background(Color.riffitSurface)
                        .cornerRadius(RR.input)
                        .overlay(
                            RoundedRectangle(cornerRadius: RR.input)
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
            .padding(.horizontal, RS.md)
            .padding(.vertical, RS.smPlus)
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
