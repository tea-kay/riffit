import Foundation

/// Singleton wrapper around the Supabase Swift SDK client.
/// Configured with the project URL and anon key from the app's
/// Info.plist (set via Xcode build settings, never hardcoded).
///
/// Usage: SupabaseClient.shared.client
class SupabaseClient {
    static let shared = SupabaseClient()

    // TODO: Initialize Supabase Swift SDK client here once
    // the Supabase project is created and the SDK is added
    // via Swift Package Manager.
    //
    // let client: SupabaseClient = ...

    private init() {
        // Will read SUPABASE_URL and SUPABASE_ANON_KEY from Info.plist
    }
}
