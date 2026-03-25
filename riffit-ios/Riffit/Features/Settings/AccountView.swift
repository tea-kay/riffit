import CoreTransferable
import PhotosUI
import SwiftUI

/// Account management screen — editable profile name and photo,
/// read-only email, and account deletion (coming soon).
struct AccountView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirm: Bool = false

    // Editable name field — seeded from currentUser on appear
    @State private var nameText: String = ""
    @State private var isSavingName: Bool = false
    @State private var nameSaveError: String?

    // Editable username field — seeded from currentUser on appear
    @State private var usernameText: String = ""
    @State private var isSavingUsername: Bool = false
    @State private var usernameSaveError: String?

    // Photo picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto: Bool = false
    @State private var photoError: String?

    private enum FocusedField {
        case name
        case username
    }
    @FocusState private var focusedField: FocusedField?

    // MARK: - Computed Properties

    /// Handle: username if set, else email prefix
    private var displayHandle: String {
        if let username = appState.currentUser?.username?.trimmingCharacters(in: .whitespacesAndNewlines),
           !username.isEmpty {
            return "@\(username)"
        }
        if let email = appState.currentUser?.email {
            let prefix = email.components(separatedBy: "@").first ?? ""
            if !prefix.isEmpty { return "@\(prefix)" }
        }
        return "@you"
    }

    /// Initials from full_name (first + last initial) or email (first letter)
    private var avatarInitials: String {
        if let name = appState.currentUser?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            let parts = name.split(separator: " ")
            if parts.count >= 2,
               let first = parts.first?.first,
               let last = parts.last?.first {
                return "\(first)\(last)".uppercased()
            }
            if let first = parts.first?.first {
                return String(first).uppercased()
            }
        }
        if let first = appState.currentUser?.email.first {
            return String(first).uppercased()
        }
        return "?"
    }

    /// Subscription tier label, capitalized
    private var tierLabel: String {
        switch appState.currentUser?.subscriptionTier {
        case .pro: return "Pro"
        default: return "Free"
        }
    }

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: RS.lg) {
                    // ── Identity card with tappable avatar ──
                    identityCard

                    // ── Profile section ──
                    accountSection("Profile") {
                        // Editable full name
                        nameField

                        // Editable username
                        usernameField

                        // Read-only email
                        readOnlyField(
                            label: "Email",
                            value: appState.currentUser?.email,
                            placeholder: "No email"
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
        .onAppear {
            // Seed editable fields from the current user
            nameText = appState.currentUser?.fullName ?? ""
            usernameText = appState.currentUser?.username ?? ""
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let item = newItem else { return }
            Task {
                await uploadPhoto(from: item)
                selectedPhotoItem = nil
            }
        }
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This feature is coming soon. Account deletion is not yet available.")
        }
    }

    // MARK: - Identity Card

    private var identityCard: some View {
        HStack(spacing: RS.smPlus) {
            // Avatar — tap to pick a new photo
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    avatarImage
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())

                    // Upload spinner overlay
                    if isUploadingPhoto {
                        Circle()
                            .fill(Color.riffitBackground.opacity(0.6))
                            .frame(width: 56, height: 56)
                        ProgressView()
                            .tint(Color.riffitPrimary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isUploadingPhoto)

            VStack(alignment: .leading, spacing: RS.xs) {
                // Tapping the @handle focuses the username field below
                Button {
                    focusedField = .username
                } label: {
                    Text(displayHandle)
                        .font(RF.heading)
                        .foregroundStyle(Color.riffitTextPrimary)
                }
                .buttonStyle(.plain)

                Text("\(tierLabel) plan")
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextSecondary)
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

    /// Resolves the avatar image: remote URL, or initials fallback
    @ViewBuilder
    private var avatarImage: some View {
        if let avatarUrlString = appState.currentUser?.avatarUrl,
           let avatarUrl = URL(string: avatarUrlString) {
            AsyncImage(url: avatarUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    initialsAvatar
                }
            }
        } else {
            initialsAvatar
        }
    }

    /// Initials circle used when no avatar image is available
    private var initialsAvatar: some View {
        Text(avatarInitials)
            .font(RF.heading)
            .foregroundStyle(Color.riffitTextPrimary)
            .frame(width: 56, height: 56)
            .background(Color.riffitTeal600)
            .clipShape(Circle())
    }

    // MARK: - Name Field

    private var nameField: some View {
        let isFocused = focusedField == .name
        return VStack(alignment: .leading, spacing: RS.xs) {
            Text("Full name")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextTertiary)

            HStack(spacing: RS.xs) {
                TextField("Add your name", text: $nameText)
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .name)

                if isSavingName {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.riffitPrimary)
                } else if isFocused {
                    Button {
                        Task { await saveName() }
                    } label: {
                        Text("Save")
                            .font(RF.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.riffitPrimary)
                    }
                } else {
                    Button { focusedField = .name } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(Color.riffitTextTertiary)
                    }
                }
            }

            if let error = nameSaveError {
                Text(error)
                    .font(RF.meta)
                    .foregroundStyle(Color.riffitDanger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RS.md)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(isFocused ? Color.riffitPrimary.opacity(0.5) : Color.riffitBorderSubtle,
                        lineWidth: isFocused ? 1 : 0.5)
        )
        .onTapGesture { focusedField = .name }
    }

    // MARK: - Username Field

    private var usernameField: some View {
        let isFocused = focusedField == .username
        return VStack(alignment: .leading, spacing: RS.xs) {
            Text("Username")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextTertiary)

            HStack(spacing: 0) {
                // The @ prefix — always visible, not part of the editable text
                Text("@")
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextTertiary)

                TextField("yourhandle", text: $usernameText)
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)

                Spacer()

                if isSavingUsername {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.riffitPrimary)
                } else if isFocused {
                    Button {
                        Task { await saveUsername() }
                    } label: {
                        Text("Save")
                            .font(RF.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.riffitPrimary)
                    }
                } else {
                    Button { focusedField = .username } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(Color.riffitTextTertiary)
                    }
                }
            }

            if let error = usernameSaveError {
                Text(error)
                    .font(RF.meta)
                    .foregroundStyle(Color.riffitDanger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RS.md)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(isFocused ? Color.riffitPrimary.opacity(0.5) : Color.riffitBorderSubtle,
                        lineWidth: isFocused ? 1 : 0.5)
        )
        .onTapGesture { focusedField = .username }
    }

    // MARK: - Save Name

    private func saveName() async {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == (appState.currentUser?.fullName ?? "") {
            focusedField = nil
            return
        }
        isSavingName = true
        nameSaveError = nil
        do {
            try await appState.updateFullName(trimmed)
            focusedField = nil
        } catch {
            nameSaveError = "Could not save name. Try again."
            print("[AccountView] Name save failed: \(error)")
        }
        isSavingName = false
    }

    // MARK: - Save Username

    private func saveUsername() async {
        // Strip @ if user accidentally typed it, then trim whitespace
        let trimmed = usernameText
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        usernameText = trimmed

        if trimmed == (appState.currentUser?.username ?? "") {
            focusedField = nil
            return
        }
        isSavingUsername = true
        usernameSaveError = nil
        do {
            try await appState.updateUsername(trimmed)
            focusedField = nil
        } catch {
            usernameSaveError = "Could not save username. Try again."
            print("[AccountView] Username save failed: \(error)")
        }
        isSavingUsername = false
    }

    // MARK: - Upload Photo

    private func uploadPhoto(from item: PhotosPickerItem) async {
        print("[AccountView] 📸 PhotosPicker onChange fired, item: \(item)")
        isUploadingPhoto = true
        photoError = nil
        defer { isUploadingPhoto = false }

        // Load raw image data from the picker item.
        // loadTransferable(type: Data.self) fails for most photo types,
        // so we load as UIImage via a Transferable wrapper instead.
        let data: Data?
        do {
            // Try loading as Data first (works for PNG/JPEG screenshots)
            data = try await item.loadTransferable(type: Data.self)
            print("[AccountView]    loadTransferable(Data) returned \(data?.count ?? 0) bytes")
        } catch {
            print("[AccountView]    loadTransferable(Data) threw: \(error)")
            data = nil
        }

        // Build a UIImage from the raw data, or fall back to loading via
        // the PickerImage Transferable wrapper (handles HEIF, Live Photos, etc.)
        let uiImage: UIImage?
        if let data, let img = UIImage(data: data) {
            uiImage = img
        } else {
            print("[AccountView]    Data didn't produce a UIImage, trying PickerImage transferable")
            do {
                if let pickerImage = try await item.loadTransferable(type: PickerImage.self) {
                    uiImage = pickerImage.uiImage
                    print("[AccountView]    PickerImage loaded OK")
                } else {
                    uiImage = nil
                    print("[AccountView]    PickerImage returned nil")
                }
            } catch {
                print("[AccountView]    PickerImage loadTransferable threw: \(error)")
                uiImage = nil
            }
        }

        guard let image = uiImage else {
            print("[AccountView] ❌ Could not create UIImage from picker item")
            photoError = "Could not load image."
            return
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
            print("[AccountView] ❌ Could not compress to JPEG")
            photoError = "Could not process image."
            return
        }
        print("[AccountView]    JPEG data ready: \(jpegData.count) bytes")

        do {
            try await appState.uploadAvatar(imageData: jpegData)
            print("[AccountView] ✅ Avatar upload + save complete")
        } catch {
            photoError = "Upload failed. Try again."
            print("[AccountView] ❌ Avatar upload failed: \(error)")
        }
    }


    // MARK: - Read-Only Field

    private func readOnlyField(
        label: String,
        value: String?,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: RS.xs) {
            Text(label)
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextTertiary)

            let displayValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if displayValue.isEmpty {
                Text(placeholder)
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextTertiary)
            } else {
                Text(displayValue)
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
}

// MARK: - PickerImage Transferable

/// A Transferable wrapper that lets PhotosPickerItem decode images
/// in any format the system supports (JPEG, HEIF, PNG, etc.)
/// by going through UIImage's broad format support.
private struct PickerImage: Transferable {
    let uiImage: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw TransferError.importFailed
            }
            return PickerImage(uiImage: image)
        }
    }

    enum TransferError: Error {
        case importFailed
    }
}
