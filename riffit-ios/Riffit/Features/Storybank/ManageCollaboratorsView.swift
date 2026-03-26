import SwiftUI

/// Full-screen view for managing collaborators on a story.
/// Accessible from StoryDetailView toolbar → "Manage people".
/// Shows all collaborators with roles, supports remove + role change.
struct ManageCollaboratorsView: View {
    let story: Story
    @ObservedObject var viewModel: StorybankViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// Collaborator pending removal confirmation
    @State private var collaboratorToRemove: StoryCollaborator?
    @State private var showRemoveConfirmation: Bool = false

    /// Whether the current user's tier has granular role permissions (Studio+)
    /// Hardcoded to false for now — Free/Pro only get the "Collaborator" role.
    private var hasRolePermissions: Bool {
        false
    }

    /// Collaborator limit for the current tier.
    /// Free: 1, Pro: 2. Studio+ will be 4/10/10.
    private var collaboratorLimit: Int {
        switch appState.currentUser?.subscriptionTier {
        case .pro: return 2
        default: return 1
        }
    }

    /// All collaborators for this story, owner first
    private var collaborators: [StoryCollaborator] {
        viewModel.collaborators(for: story.id)
    }

    /// Owner display name: @username > fullName > @email_prefix, with "(You)" suffix.
    /// Same logic as SettingsView.displayName.
    private var ownerDisplayName: String {
        let baseName: String = {
            if let username = appState.currentUser?.username?.trimmingCharacters(in: .whitespacesAndNewlines),
               !username.isEmpty {
                return "@\(username)"
            }
            if let fullName = appState.currentUser?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !fullName.isEmpty {
                return fullName
            }
            if let email = appState.currentUser?.email {
                let prefix = email.components(separatedBy: "@").first ?? ""
                if !prefix.isEmpty { return "@\(prefix)" }
            }
            return "You"
        }()
        return "\(baseName) (You)"
    }

    /// Non-owner collaborator count (owners don't count toward the limit)
    private var activeCollaboratorCount: Int {
        collaborators.filter { $0.role != .owner && $0.status == .accepted }.count
    }

    var body: some View {
        NavigationStack {
            List {
                // Collaborator count header
                Section {
                    HStack {
                        Text("\(activeCollaboratorCount) of \(collaboratorLimit) collaborator\(collaboratorLimit == 1 ? "" : "s")")
                            .font(RF.bodySm)
                            .foregroundStyle(Color.riffitTextSecondary)

                        Spacer()

                        if activeCollaboratorCount >= collaboratorLimit {
                            HStack(spacing: RS.xs) {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                Text("Upgrade for more")
                                    .font(RF.caption)
                            }
                            .foregroundStyle(Color.riffitPrimary)
                        }
                    }
                    .listRowBackground(Color.riffitBackground)
                    .listRowSeparator(.hidden)
                }

                // Collaborator list
                Section {
                    ForEach(collaborators) { collaborator in
                        CollaboratorRow(
                            collaborator: collaborator,
                            hasRolePermissions: true,
                            isOwnerView: true,
                            userDisplayName: collaborator.role == .owner
                                ? ownerDisplayName
                                : viewModel.collaboratorDisplayName(for: collaborator, currentUserId: appState.currentUser?.id),
                            userAvatarUrl: collaborator.role == .owner
                                ? appState.currentUser?.avatarUrl
                                : viewModel.collaboratorAvatarUrl(for: collaborator, currentUserId: appState.currentUser?.id),
                            onChangeRole: { newRole in
                                viewModel.updateCollaboratorRole(collaborator, to: newRole)
                            },
                            onRemove: {
                                collaboratorToRemove = collaborator
                                showRemoveConfirmation = true
                            }
                        )
                        .onAppear {
                            if collaborator.role != .owner {
                                viewModel.cacheUserInfo(userId: collaborator.userId)
                            }
                        }
                        .listRowBackground(Color.riffitBackground)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: RS.xs, leading: RS.md,
                            bottom: RS.xs, trailing: RS.md
                        ))
                        // Swipe to remove (non-owners only)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if collaborator.role != .owner {
                                Button(role: .destructive) {
                                    collaboratorToRemove = collaborator
                                    showRemoveConfirmation = true
                                } label: {
                                    Label("Remove", systemImage: "person.badge.minus")
                                }
                            }
                        }
                    }
                } header: {
                    Text("People")
                        .font(RF.tag)
                        .textCase(.uppercase)
                        .tracking(0.08 * 12)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.riffitBackground)
            .navigationTitle("Manage People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.riffitPrimary)
                }
            }
            .alert("Remove Collaborator", isPresented: $showRemoveConfirmation) {
                Button("Remove", role: .destructive) {
                    if let collaborator = collaboratorToRemove {
                        viewModel.removeCollaborator(collaborator)
                    }
                    collaboratorToRemove = nil
                }
                Button("Cancel", role: .cancel) {
                    collaboratorToRemove = nil
                }
            } message: {
                Text("They will lose access to this story immediately.")
            }
        }
        .presentationBackground(Color.riffitBackground)
    }
}

// MARK: - Collaborator Row

/// A single collaborator row: avatar + name + role pill + actions menu.
/// Reused in both ManageCollaboratorsView and the People section of StoryDetailView.
/// Pass userDisplayName and userAvatarUrl to show real profile data (e.g. for the owner row).
struct CollaboratorRow: View {
    let collaborator: StoryCollaborator
    let hasRolePermissions: Bool
    let isOwnerView: Bool
    /// The display name to show — e.g. "@sarah (You)" for owner, "Collaborator" for others.
    var userDisplayName: String?
    /// Avatar URL from the user record — shows AsyncImage when available.
    var userAvatarUrl: String?
    var onChangeRole: ((CollaboratorRole) -> Void)?
    var onRemove: (() -> Void)?

    /// Resolved display name: uses provided name, falls back to role-based placeholder.
    private var displayName: String {
        if let name = userDisplayName, !name.isEmpty {
            return name
        }
        if collaborator.role == .owner {
            return "You"
        }
        return "Collaborator"
    }

    /// Initials for avatar fallback — uses the first non-@ character
    private var avatarInitial: String {
        let name = displayName.replacingOccurrences(of: "@", with: "")
        return String(name.first ?? Character("?")).uppercased()
    }

    var body: some View {
        HStack(spacing: RS.smPlus) {
            // Avatar — 32×32 circle, AsyncImage from URL or initials fallback
            if let urlString = userAvatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    initialsCircle
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                initialsCircle
            }

            // Name + status
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(RF.label)
                    .foregroundStyle(Color.riffitTextPrimary)

                if collaborator.status == .pending {
                    Text("Pending")
                        .font(RF.meta)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
            }

            Spacer()

            // Role pill
            rolePill

            // Actions menu (not for owner row)
            if collaborator.role != .owner && isOwnerView {
                Menu {
                    if hasRolePermissions {
                        // Role change options
                        ForEach([CollaboratorRole.editor, .viewer, .commenter, .collaborator], id: \.self) { role in
                            if role != collaborator.role {
                                Button {
                                    onChangeRole?(role)
                                } label: {
                                    Label(role.displayName, systemImage: roleIcon(for: role))
                                }
                            }
                        }
                        Divider()
                    }

                    Button(role: .destructive) {
                        onRemove?()
                    } label: {
                        Label("Remove from story", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(Color.riffitTextTertiary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(RS.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    /// Initials fallback circle — always teal600 background, matching Settings pattern
    private var initialsCircle: some View {
        Text(avatarInitial)
            .font(RF.caption)
            .foregroundStyle(Color.riffitTextPrimary)
            .frame(width: 32, height: 32)
            .background(Color.riffitTeal600)
            .clipShape(Circle())
    }

    // MARK: - Role Pill

    /// Color-coded capsule showing the collaborator's role.
    /// Owner: primary tint + gold text
    /// Editor/Collaborator: teal tint + teal text
    /// Viewer/Commenter: surface + secondary text
    private var rolePill: some View {
        Text(collaborator.role.displayName)
            .font(RF.tag)
            .foregroundStyle(rolePillTextColor)
            .padding(.vertical, RS.xs)
            .padding(.horizontal, RS.smPlus)
            .background(rolePillBackground)
            .clipShape(Capsule())
    }

    private var rolePillTextColor: Color {
        switch collaborator.role {
        case .owner:
            return Color.riffitPrimary
        case .editor, .collaborator:
            return Color.riffitTeal400
        case .viewer, .commenter:
            return Color.riffitTextSecondary
        }
    }

    private var rolePillBackground: Color {
        switch collaborator.role {
        case .owner:
            return Color.riffitPrimaryTint
        case .editor, .collaborator:
            return Color.riffitTealTint
        case .viewer, .commenter:
            return Color.riffitElevated
        }
    }

    private func roleIcon(for role: CollaboratorRole) -> String {
        switch role {
        case .editor: return "pencil"
        case .viewer: return "eye"
        case .commenter: return "text.bubble"
        case .owner: return "star"
        case .collaborator: return "person"
        }
    }
}
