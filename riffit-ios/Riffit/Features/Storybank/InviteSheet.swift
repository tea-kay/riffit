import SwiftUI

/// Bottom sheet for inviting collaborators to a story.
/// Two sections: shareable invite link + search by username.
/// Role picker only appears for Studio+ tiers (role_permissions entitlement).
struct InviteSheet: View {
    let story: Story
    @ObservedObject var viewModel: StorybankViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// Selected role for new invites — defaults to .collaborator for Free/Pro
    @State private var selectedRole: CollaboratorRole = .collaborator

    /// Username search query
    @State private var searchQuery: String = ""

    /// Debounced search results (stubbed — in-memory user list for now)
    @State private var searchResults: [RiffitUser] = []

    /// Whether the "Copied!" feedback is showing
    @State private var showCopiedFeedback: Bool = false

    /// Controls the share sheet presentation
    @State private var showShareSheet: Bool = false

    /// Whether an invite link is currently being created
    @State private var isCreatingLink: Bool = false

    /// The URL string to share — built from the real Supabase invite link
    @State private var shareUrl: String = ""

    /// Whether the current user's tier has granular role permissions (Studio+)
    /// Hardcoded to false for now — Free/Pro only get the "Collaborator" role.
    private var hasRolePermissions: Bool {
        false
    }

    /// The invite link URL for display. Shows the real link if one exists,
    /// otherwise shows a placeholder until the user creates one.
    private var inviteLinkText: String {
        if let existing = viewModel.activeInviteLink(for: story.id) {
            return inviteUrl(for: existing)
        }
        return "Tap Copy or Share to generate a link"
    }

    /// Builds the shareable URL from an invite link record.
    private func inviteUrl(for link: StoryInviteLink) -> String {
        var url = "riffit.app/invite/\(link.token)"
        if let refId = link.referralUserId {
            url += "?ref=\(refId.uuidString)"
        }
        return url
    }

    var body: some View {
        VStack(spacing: RS.lg) {
            // Drag handle
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, RS.smPlus)

            Text("Invite People")
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)

            ScrollView {
                VStack(spacing: RS.lg) {
                    // MARK: - Role Picker (Studio+ only)
                    if hasRolePermissions {
                        rolePicker
                    }

                    // MARK: - Invite Link Section
                    inviteLinkSection

                    // MARK: - Search by Username Section
                    usernameSearchSection
                }
                .padding(.horizontal, RS.md)
            }
        }
        .background(Color.riffitBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(CGFloat(RR.modal))
        .presentationBackground(Color.riffitBackground)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareUrl])
        }
    }

    // MARK: - Role Picker

    /// Horizontal pill row: Editor · Viewer · Commenter
    /// Only shown for Studio+ tiers.
    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            Text("ROLE")
                .font(RF.tag)
                .textCase(.uppercase)
                .tracking(0.08 * 12)
                .foregroundStyle(Color.riffitTextTertiary)

            HStack(spacing: RS.sm) {
                ForEach([CollaboratorRole.editor, .viewer, .commenter], id: \.self) { role in
                    Button {
                        selectedRole = role
                    } label: {
                        Text(role.displayName)
                            .font(RF.tag)
                            .foregroundStyle(
                                selectedRole == role
                                    ? Color.riffitTeal400
                                    : Color.riffitTextSecondary
                            )
                            .padding(.vertical, RS.xs + 2)
                            .padding(.horizontal, RS.smPlus)
                            .background(
                                selectedRole == role
                                    ? Color.riffitTealTint
                                    : Color.riffitElevated
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selectedRole == role
                                            ? Color.riffitTeal400.opacity(0.5)
                                            : Color.riffitBorderDefault,
                                        lineWidth: 0.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Invite Link Section

    private var inviteLinkSection: some View {
        VStack(alignment: .leading, spacing: RS.smPlus) {
            Text("SHARE INVITE LINK")
                .font(RF.tag)
                .textCase(.uppercase)
                .tracking(0.08 * 12)
                .foregroundStyle(Color.riffitTextTertiary)

            // Link display + action buttons
            HStack(spacing: RS.sm) {
                // Truncated link in mono style
                Text(inviteLinkText)
                    .font(RF.url)
                    .foregroundStyle(Color.riffitTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(RS.smPlus)
                    .background(Color.riffitElevated)
                    .cornerRadius(RR.input)
                    .overlay(
                        RoundedRectangle(cornerRadius: RR.input)
                            .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
                    )

                // Copy button — creates invite link in Supabase if needed, then copies URL
                Button {
                    Task {
                        guard let url = await getOrCreateInviteUrl() else { return }
                        UIPasteboard.general.string = url
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        showCopiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopiedFeedback = false
                        }
                    }
                } label: {
                    Group {
                        if isCreatingLink {
                            ProgressView()
                                .tint(Color.riffitTeal400)
                        } else {
                            Text(showCopiedFeedback ? "Copied!" : "Copy")
                        }
                    }
                    .font(RF.tag)
                    .foregroundStyle(Color.riffitTeal400)
                    .padding(.vertical, RS.sm)
                    .padding(.horizontal, RS.smPlus)
                    .background(Color.riffitTealTint)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isCreatingLink)

                // Share button — creates invite link in Supabase if needed, then opens share sheet
                Button {
                    Task {
                        guard let url = await getOrCreateInviteUrl() else { return }
                        shareUrl = url
                        showShareSheet = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundStyle(Color.riffitTeal400)
                        .padding(RS.sm)
                        .background(Color.riffitTealTint)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isCreatingLink)
            }
        }
    }

    // MARK: - Username Search Section

    private var usernameSearchSection: some View {
        VStack(alignment: .leading, spacing: RS.smPlus) {
            Text("FIND ON RIFFIT")
                .font(RF.tag)
                .textCase(.uppercase)
                .tracking(0.08 * 12)
                .foregroundStyle(Color.riffitTextTertiary)

            // Search field
            HStack(spacing: RS.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(Color.riffitTextTertiary)

                TextField("Search by username...", text: $searchQuery)
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: searchQuery) { _, newValue in
                        performSearch(query: newValue)
                    }
            }
            .padding(RS.smPlus)
            .background(Color.riffitElevated)
            .cornerRadius(RR.input)
            .overlay(
                RoundedRectangle(cornerRadius: RR.input)
                    .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
            )

            // Search results
            if !searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(searchResults) { user in
                        Button {
                            inviteUser(user)
                        } label: {
                            HStack(spacing: RS.smPlus) {
                                // Avatar
                                userAvatar(for: user)

                                // Name + username
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.fullName ?? "Riffit User")
                                        .font(RF.label)
                                        .foregroundStyle(Color.riffitTextPrimary)

                                    if let username = user.username {
                                        Text("@\(username)")
                                            .font(RF.caption)
                                            .foregroundStyle(Color.riffitTextSecondary)
                                    }
                                }

                                Spacer()

                                // Invite indicator
                                Image(systemName: "plus.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(Color.riffitTeal400)
                            }
                            .padding(RS.smPlus)
                        }
                        .buttonStyle(.plain)

                        if user.id != searchResults.last?.id {
                            Divider()
                                .overlay(Color.riffitBorderSubtle)
                        }
                    }
                }
                .background(Color.riffitSurface)
                .cornerRadius(RR.input)
                .overlay(
                    RoundedRectangle(cornerRadius: RR.input)
                        .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
                )
            } else if !searchQuery.isEmpty {
                Text("No users found")
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RS.md)
            }
        }
    }

    // MARK: - Helpers

    /// Returns the URL for an existing active invite link, or creates a new one
    /// in Supabase and returns that URL. Returns nil only if the INSERT fails.
    private func getOrCreateInviteUrl() async -> String? {
        // Reuse an existing active link if one exists
        if let existing = viewModel.activeInviteLink(for: story.id) {
            return inviteUrl(for: existing)
        }

        // Create a new link in Supabase
        guard let userId = appState.currentUser?.id else { return nil }
        isCreatingLink = true
        defer { isCreatingLink = false }

        let role: CollaboratorRole = hasRolePermissions ? selectedRole : .collaborator
        guard let link = await viewModel.createInviteLink(
            for: story.id,
            createdBy: userId,
            role: role,
            referralUserId: userId
        ) else {
            return nil
        }
        return inviteUrl(for: link)
    }

    /// 32×32 avatar circle for search result users
    private func userAvatar(for user: RiffitUser) -> some View {
        Group {
            if let urlString = user.avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    initialsCircle(for: user)
                }
            } else {
                initialsCircle(for: user)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }

    /// Initials fallback for user avatar
    private func initialsCircle(for user: RiffitUser) -> some View {
        let initial: String = {
            if let name = user.fullName, let first = name.first {
                return String(first).uppercased()
            }
            return String(user.email.first ?? Character("?")).uppercased()
        }()

        return Text(initial)
            .font(RF.caption)
            .foregroundStyle(Color.riffitTextPrimary)
            .frame(width: 32, height: 32)
            .background(Color.riffitTeal600)
            .clipShape(Circle())
    }

    /// Searches Supabase users by username, full_name, or email (ILIKE).
    /// Most new users only have email set, so email is the most reliable match.
    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        let pattern = "%\(trimmed)%"
        Task {
            do {
                let response = try await supabase
                    .from("users")
                    .select()
                    .or("username.ilike.\(pattern),full_name.ilike.\(pattern),email.ilike.\(pattern)")
                    .limit(10)
                    .execute()

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let str = try container.decode(String.self)
                    let f1 = ISO8601DateFormatter()
                    f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let f2 = ISO8601DateFormatter()
                    f2.formatOptions = [.withInternetDateTime]
                    if let date = f1.date(from: str) { return date }
                    if let date = f2.date(from: str) { return date }
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
                }

                let users = try decoder.decode([RiffitUser].self, from: response.data)
                // Exclude the current user from results
                let currentId = appState.currentUser?.id
                await MainActor.run {
                    searchResults = users.filter { $0.id != currentId }
                }
            } catch {
                print("[InviteSheet] performSearch FAILED: \(error)")
            }
        }
    }

    /// Invite a user to this story with the selected role
    private func inviteUser(_ user: RiffitUser) {
        guard let ownerId = appState.currentUser?.id else { return }
        Task {
            await viewModel.addCollaborator(
                to: story.id,
                userId: user.id,
                role: hasRolePermissions ? selectedRole : .collaborator,
                invitedBy: ownerId
            )
        }
        // Clear search after invite
        searchQuery = ""
        searchResults = []
    }
}
