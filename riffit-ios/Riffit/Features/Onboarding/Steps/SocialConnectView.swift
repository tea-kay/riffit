import SwiftUI

/// Step 3 of onboarding (optional): connect social accounts.
/// The user can add their social handles for brand context,
/// or skip this step entirely. Skipping doesn't block anything.
struct SocialConnectView: View {
    let onComplete: () -> Void

    @State private var accounts: [SocialAccountInput] = Platform.allCases.map { platform in
        SocialAccountInput(platform: platform, handle: "")
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            ScrollView {
                VStack(spacing: .md) {
                    ForEach($accounts) { $account in
                        SocialAccountRow(account: $account)
                    }
                }
                .padding(.horizontal, .md)
                .padding(.bottom, .lg)
            }

            bottomButtons
        }
        .background(Color.riffitBackground)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: .sm) {
            Text("Connect your accounts")
                .riffitDisplay()
                .foregroundStyle(Color.riffitTextPrimary)

            Text("Add your social handles so we can understand your brand context. This is optional — you can always do this later.")
                .riffitBody()
                .foregroundStyle(Color.riffitTextSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, .lg)
        .padding(.top, .xl)
        .padding(.bottom, .lg)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: .smPlus) {
            Divider()
                .overlay(Color.riffitBorderSubtle)

            VStack(spacing: .smPlus) {
                // Continue button — only enabled if at least one handle is filled
                RiffitButton(title: "Continue", variant: .primary) {
                    // TODO: Save filled accounts to Supabase
                    onComplete()
                }

                // Skip button
                Button {
                    onComplete()
                } label: {
                    Text("Skip for now")
                        .riffitCallout()
                        .foregroundStyle(Color.riffitTextSecondary)
                }
            }
            .padding(.horizontal, .md)
            .padding(.bottom, .md)
        }
        .background(Color.riffitBackground)
    }
}

// MARK: - Platform Enum (for onboarding input)

/// The social platforms a creator can connect.
/// Mirrors the platform check constraint in the database.
enum Platform: String, CaseIterable, Identifiable {
    case instagram
    case tiktok
    case youtube
    case linkedin
    case x

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .youtube: return "YouTube"
        case .linkedin: return "LinkedIn"
        case .x: return "X"
        }
    }

    var icon: String {
        // Using SF Symbols where available, generic for others
        switch self {
        case .instagram: return "camera"
        case .tiktok: return "music.note"
        case .youtube: return "play.rectangle"
        case .linkedin: return "briefcase"
        case .x: return "at"
        }
    }

    var placeholder: String {
        switch self {
        case .instagram: return "@yourhandle"
        case .tiktok: return "@yourhandle"
        case .youtube: return "@yourchannel"
        case .linkedin: return "your-profile"
        case .x: return "@yourhandle"
        }
    }
}

// MARK: - Social Account Input Model

/// Temporary model for collecting social handles during onboarding.
struct SocialAccountInput: Identifiable {
    let id = UUID()
    let platform: Platform
    var handle: String
}

// MARK: - Social Account Row

/// A row for entering a social media handle.
struct SocialAccountRow: View {
    @Binding var account: SocialAccountInput

    var body: some View {
        HStack(spacing: .smPlus) {
            // Platform icon
            Image(systemName: account.platform.icon)
                .font(.body)
                .foregroundStyle(Color.riffitTeal400)
                .frame(width: 36, height: 36)
                .background(Color.riffitTealTint)
                .cornerRadius(.tagRadius)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.platform.displayName)
                    .riffitLabel()
                    .foregroundStyle(Color.riffitTextTertiary)

                TextField(account.platform.placeholder, text: $account.handle)
                    .modifier(RiffitTextFieldStyle())
                    .foregroundStyle(Color.riffitTextPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(.inputRadius)
        .overlay(
            RoundedRectangle(cornerRadius: .inputRadius)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }
}
