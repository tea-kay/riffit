import SwiftUI

/// The sign-in screen. Uses Apple Sign In via Supabase Auth.
/// Shown when the user is not authenticated.
struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        // TODO: Implement Apple Sign In UI (Phase 1, Step 5)
        Text("Auth")
    }
}
