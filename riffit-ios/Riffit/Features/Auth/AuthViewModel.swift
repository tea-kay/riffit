import SwiftUI

/// Handles authentication logic — Apple Sign In via Supabase.
@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // TODO: Implement sign in / sign out (Phase 1, Step 5)
}
