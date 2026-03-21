import Foundation
import Supabase

// MARK: - Shared Supabase Client
// This is the single shared instance of the Supabase client for the entire app.
// Do not create additional SupabaseClient instances anywhere — always use `supabase`.

// DEV ONLY: These credentials are the publishable anon key and project URL.
// Before TestFlight / App Store builds, move both values into an xcconfig file
// so they are not committed to source control in production.
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://glamdnebtzrrbhxmyzho.supabase.co")!,
    supabaseKey: "sb_publishable_Hx6oZG5fVvfw-aHtTAVlhQ_yqmHefLA"
)
