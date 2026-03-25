import SwiftUI

/// Full-screen view shown when opening a collaboration invite link.
/// Displays the story preview and a one-tap join button.
/// Handles three states: resolved invite (happy path), error, and loading.
struct CollabJoinView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: StorybankViewModel

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            if let error = appState.inviteError {
                errorState(error)
            } else if let resolved = appState.resolvedInvite {
                invitePreview(resolved)
            } else {
                // Loading — resolving the token
                VStack(spacing: RS.md) {
                    ProgressView()
                        .tint(Color.riffitPrimary)
                    Text("Loading invite...")
                        .font(RF.bodyMd)
                        .foregroundStyle(Color.riffitTextSecondary)
                }
            }
        }
        .onAppear {
            // Resolve the pending invite token when view appears
            if let token = appState.pendingInviteToken, appState.resolvedInvite == nil, appState.inviteError == nil {
                viewModel.resolveInviteToken(token, appState: appState)
            }
        }
    }

    // MARK: - Invite Preview (Happy Path)

    private func invitePreview(_ resolved: AppState.ResolvedInvite) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Owner avatar — 64×64
            ownerAvatar(name: resolved.ownerName, avatarUrl: resolved.ownerAvatarUrl)
                .padding(.bottom, RS.md)

            // Owner name
            Text(resolved.ownerName)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextPrimary)
                .padding(.bottom, RS.xs)

            // Story title — Georgia Bold Italic
            Text(resolved.storyTitle)
                .font(RF.title)
                .foregroundStyle(Color.riffitTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RS.xl)
                .padding(.bottom, RS.sm)

            // "invited you to collaborate"
            Text("invited you to collaborate")
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextSecondary)
                .padding(.bottom, RS.lg)

            // Asset count preview
            countsPreview(assets: resolved.assetCount, references: resolved.referenceCount)
                .padding(.bottom, RS.xl2)

            // Join button
            if appState.isAuthenticated {
                RiffitButton(title: "Join", variant: .primary) {
                    joinStory(resolved)
                }
                .padding(.horizontal, RS.xl)
            } else {
                // Not signed in — "Join with Apple" triggers auth flow
                // The actual Apple Sign In is handled by AuthView after dismiss.
                // For now, dismiss this view so AuthView is visible, token stays pending.
                RiffitButton(title: "Join with Apple", variant: .primary) {
                    // Dismiss CollabJoinView — AuthView will be shown by RootView.
                    // After auth completes, AppState.checkPendingInviteAfterAuth()
                    // re-shows this view with the user now signed in.
                    appState.showCollabJoinView = false
                }
                .padding(.horizontal, RS.xl)
            }

            // "No thanks" dismiss button
            Button {
                appState.clearPendingInvite()
            } label: {
                Text("No thanks")
                    .font(RF.bodySm)
                    .foregroundStyle(Color.riffitTextTertiary)
            }
            .padding(.top, RS.md)

            Spacer()
        }
    }

    // MARK: - Error States

    private func errorState(_ error: AppState.InviteError) -> some View {
        VStack(spacing: RS.lg) {
            Spacer()

            Image(systemName: errorIcon(error))
                .font(.system(size: 48))
                .foregroundStyle(Color.riffitTextTertiary)

            Text(errorTitle(error))
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)
                .multilineTextAlignment(.center)

            Text(errorMessage(error))
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, RS.xl)

            RiffitButton(title: errorButtonTitle(error), variant: .secondary) {
                appState.clearPendingInvite()
            }
            .padding(.horizontal, RS.xl)

            Spacer()
        }
    }

    private func errorIcon(_ error: AppState.InviteError) -> String {
        switch error {
        case .expired: return "clock.badge.xmark"
        case .notFound: return "questionmark.circle"
        case .alreadyMember: return "checkmark.circle"
        }
    }

    private func errorTitle(_ error: AppState.InviteError) -> String {
        switch error {
        case .expired: return "This invite has expired"
        case .notFound: return "Invite not found"
        case .alreadyMember: return "You're already part of this story"
        }
    }

    private func errorMessage(_ error: AppState.InviteError) -> String {
        switch error {
        case .expired: return "Ask the story owner to send a new invite link."
        case .notFound: return "This invite link may have been revoked or is invalid."
        case .alreadyMember: return "You already have access to this story in your Storybank."
        }
    }

    private func errorButtonTitle(_ error: AppState.InviteError) -> String {
        switch error {
        case .alreadyMember: return "Go to Storybank"
        default: return "Dismiss"
        }
    }

    // MARK: - Actions

    private func joinStory(_ resolved: AppState.ResolvedInvite) {
        guard let userId = appState.currentUser?.id else { return }

        viewModel.joinStoryFromInvite(
            inviteLink: resolved.inviteLink,
            userId: userId
        )

        // Clear the invite state and dismiss
        appState.clearPendingInvite()
    }

    // MARK: - Subviews

    /// 64×64 owner avatar with initials fallback
    private func ownerAvatar(name: String, avatarUrl: String?) -> some View {
        Group {
            if let urlString = avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    initialsCircle(name: name)
                }
            } else {
                initialsCircle(name: name)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
    }

    private func initialsCircle(name: String) -> some View {
        Text(String(name.first ?? Character("?")))
            .font(RF.heading)
            .foregroundStyle(Color.riffitTextPrimary)
            .frame(width: 64, height: 64)
            .background(Color.riffitTeal600)
            .clipShape(Circle())
    }

    /// "12 assets · 3 references" preview
    private func countsPreview(assets: Int, references: Int) -> some View {
        let parts: [String] = {
            var result: [String] = []
            if assets > 0 {
                result.append("\(assets) asset\(assets == 1 ? "" : "s")")
            }
            if references > 0 {
                result.append("\(references) reference\(references == 1 ? "" : "s")")
            }
            return result
        }()

        return Group {
            if parts.isEmpty {
                EmptyView()
            } else {
                Text(parts.joined(separator: " · "))
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextTertiary)
            }
        }
    }
}
