import Foundation

/// Typed wrappers for calling Supabase Edge Functions.
/// Each function matches an edge function defined in the backend.
/// The Swift app never calls external APIs directly — all AI and
/// transcription calls go through these edge functions.
class EdgeFunctions {
    // TODO: Implement typed wrappers once Supabase SDK is added.
    // Each method will call supabase.functions.invoke(...)
    //
    // func analyzeVideo(url: String, platform: String, creatorProfileId: UUID) async throws -> AnalyzeVideoResponse
    // func scoreAlignment(inspirationVideoId: UUID, creatorProfileId: UUID) async throws -> ScoreAlignmentResponse
    // func generateBrief(inspirationVideoId: UUID, creatorProfileId: UUID, userSelections: [String: Any]) async throws -> GenerateBriefResponse
    // func runInterview(sessionId: UUID, userMessage: String) async throws -> RunInterviewResponse
    // func transcribeAudio(audioUrl: String) async throws -> TranscribeAudioResponse
}
