import SwiftUI

/// Manages referral program data — earnings, invite counts, and clipboard actions.
/// All values are placeholder/zero for now. Supabase integration comes later.
@MainActor
class EarnViewModel: ObservableObject {
    @Published var referralCode: String = ""
    @Published var totalEarned: Double = 0
    @Published var thisMonthEarned: Double = 0
    @Published var inviteCount: Int = 0
    @Published var payingCount: Int = 0
    @Published var networkCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var linkCopied: Bool = false

    var referralLink: String {
        "riffit.app/r/\(referralCode)"
    }

    /// Copies the referral link to the system clipboard and shows
    /// a brief "Copied!" confirmation that reverts after 2 seconds.
    func copyLink() {
        UIPasteboard.general.string = referralLink
        linkCopied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            linkCopied = false
        }
    }

    /// Seeds the referral code from the authenticated user's username or id.
    func seedCode(from user: RiffitUser?) {
        guard let user else { return }
        if let username = user.username?.trimmingCharacters(in: .whitespacesAndNewlines),
           !username.isEmpty {
            referralCode = username
        } else {
            // Fall back to first 8 chars of user ID
            referralCode = String(user.id.uuidString.prefix(8)).lowercased()
        }
    }

    // Future: func fetchEarnings() async { ... }
    // Future: func fetchNetwork() async { ... }
}
