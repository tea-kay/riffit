import PhotosUI
import SwiftUI

/// Account management screen — profile image, editable name/username,
/// workspace actions, and account deletion.
struct AccountView: View {
    @State private var showComingSoon: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    // Persisted profile data — will be replaced with Supabase auth later
    @AppStorage("riffit_full_name") private var fullName: String = "Timothy"
    @AppStorage("riffit_username") private var username: String = ""
    @AppStorage("riffit_profile_image") private var profileImageBase64: String = ""

    @FocusState private var focusedField: ProfileField?

    private enum ProfileField {
        case fullName
        case username
    }

    /// Display name: @username if set, otherwise full name
    private var displayName: String {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUsername.isEmpty { return "@\(trimmedUsername)" }
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { return trimmedName }
        return "Your name"
    }

    /// First letter of display name for avatar fallback (skips @ prefix)
    private var avatarInitial: String {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedUsername.isEmpty, let first = trimmedUsername.first {
            return String(first).uppercased()
        }
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmedName.first else { return "?" }
        return String(first).uppercased()
    }

    /// Loads the profile image from base64 storage
    private var profileImage: UIImage? {
        guard !profileImageBase64.isEmpty,
              let data = Data(base64Encoded: profileImageBase64)
        else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: RS.lg) {
                    // ── Identity card with interactive avatar ──
                    identityCard

                    // ── Profile section (editable fields) ──
                    accountSection("Profile") {
                        profileField(
                            label: "Full name",
                            placeholder: "Your full name",
                            text: $fullName,
                            field: .fullName
                        )

                        profileField(
                            label: "Username",
                            placeholder: "yourhandle",
                            text: $username,
                            field: .username,
                            prefix: "@"
                        )
                    }

                    // ── Workspace section ──
                    accountSection("Workspace") {
                        workspaceRow(
                            icon: "person.badge.plus",
                            title: "New account",
                            subtitle: "Create a creator or agency account"
                        )

                        workspaceRow(
                            icon: "arrow.left.arrow.right",
                            title: "Switch account",
                            subtitle: "Move between your accounts"
                        )

                        workspaceRow(
                            icon: "person.2.fill",
                            title: "Join workspace",
                            subtitle: "Enter an invite code to join a team"
                        )
                    }

                    // ── Danger section ──
                    accountSection("Danger") {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: RS.smPlus) {
                                Image(systemName: "trash.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.riffitDanger)
                                    .frame(width: 28, height: 28)
                                    .background(Color.riffitDangerTint)
                                    .cornerRadius(RR.tag)

                                Text("Delete account")
                                    .font(RF.bodyMd)
                                    .foregroundStyle(Color.riffitDanger)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
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
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, RS.md)
                .padding(.top, RS.smPlus)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Account")
                    .font(RF.title)
                    .foregroundStyle(Color.riffitTextPrimary)
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let item = newItem else { return }
            Task {
                await loadPhoto(from: item)
                selectedPhotoItem = nil
            }
        }
        .sheet(isPresented: $showComingSoon) {
            comingSoonSheet
        }
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("Delete account", role: .destructive) {
                // TODO: Wire to account deletion
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your library, stories, and all your data. This cannot be undone.")
        }
    }

    // MARK: - Photo Loading

    private func loadPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        // Compress to JPEG for reasonable base64 size
        guard let uiImage = UIImage(data: data),
              let compressed = uiImage.jpegData(compressionQuality: 0.5)
        else { return }
        profileImageBase64 = compressed.base64EncodedString()
    }

    // MARK: - Identity Card

    private var identityCard: some View {
        HStack(spacing: RS.smPlus) {
            // Interactive avatar — tap to open photo library directly
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    // Avatar circle
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.riffitTeal400, lineWidth: 2)
                            )
                    } else {
                        Text(avatarInitial)
                            .font(.custom("DMSans-Medium", size: 22))
                            .foregroundStyle(Color.riffitTeal400)
                            .frame(width: 56, height: 56)
                            .background(Color.riffitTealTint)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.riffitTeal400, lineWidth: 2)
                            )
                    }

                    // Camera badge
                    Image(systemName: "camera.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.riffitOnPrimary)
                        .frame(width: 18, height: 18)
                        .background(Color.riffitPrimary)
                        .clipShape(Circle())
                        .offset(x: 2, y: 2)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: RS.xs) {
                // Display name — @username if set, otherwise full name
                Text(displayName)
                    .font(.custom("Lora-Bold", size: 17))
                    .foregroundStyle(Color.riffitTextPrimary)

                // Account type + plan tier
                HStack(spacing: RS.sm) {
                    Text("Creator")
                        .font(RF.tag)
                        .foregroundStyle(Color.riffitTeal400)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(Color.riffitTealTint)
                        .clipShape(Capsule())

                    Text("Free plan")
                        .font(RF.caption)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
            }

            Spacer()
        }
        .padding(RS.md)
        .background(Color.riffitSurface)
        .cornerRadius(RR.card)
        .overlay(
            RoundedRectangle(cornerRadius: RR.card)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Profile Field

    private func profileField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: ProfileField,
        prefix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: RS.xs) {
            Text(label)
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextTertiary)

            HStack(spacing: RS.xs) {
                if let prefix {
                    Text(prefix)
                        .font(RF.bodyMd)
                        .foregroundStyle(Color.riffitTextTertiary)
                }

                TextField(placeholder, text: text)
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .autocorrectionDisabled(field == .username)
                    .textInputAutocapitalization(field == .username ? .never : .words)
                    .focused($focusedField, equals: field)

                // Pencil when not focused, Done button when focused
                if focusedField == field {
                    Button {
                        focusedField = nil
                    } label: {
                        Text("Done")
                            .font(RF.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.riffitPrimary)
                    }
                } else {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
            }
        }
        .padding(RS.md)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    // MARK: - Section Builder

    private func accountSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RS.sm) {
            Text(title)
                .font(RF.tag)
                .textCase(.uppercase)
                .tracking(0.06 * 11)
                .foregroundStyle(Color.riffitTextTertiary)

            content()
        }
    }

    // MARK: - Workspace Row

    private func workspaceRow(icon: String, title: String, subtitle: String) -> some View {
        Button {
            showComingSoon = true
        } label: {
            HStack(spacing: RS.smPlus) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Color.riffitTeal400)
                    .frame(width: 28, height: 28)
                    .background(Color.riffitTealTint)
                    .cornerRadius(RR.tag)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(RF.bodyMd)
                        .foregroundStyle(Color.riffitTextPrimary)

                    Text(subtitle)
                        .font(RF.meta)
                        .foregroundStyle(Color.riffitTextTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
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
        .buttonStyle(.plain)
    }

    // MARK: - Coming Soon Sheet

    private var comingSoonSheet: some View {
        VStack(spacing: RS.lg) {
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, RS.smPlus)

            Spacer()

            Text("Riffit")
                .font(.custom("Lora-Bold", size: 20))
                .foregroundStyle(Color.riffitPrimary)

            Text("Coming in a future update")
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextSecondary)

            Spacer()

            RiffitButton(title: "Got it", variant: .secondary) {
                showComingSoon = false
            }
            .padding(.bottom, RS.lg)
        }
        .padding(.horizontal, RS.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.riffitBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(RR.modal)
        .presentationBackground(Color.riffitBackground)
    }
}
