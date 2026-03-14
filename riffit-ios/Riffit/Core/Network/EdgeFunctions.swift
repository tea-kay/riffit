import Foundation

/// Typed wrappers for calling Supabase Edge Functions.
/// Each method matches an edge function defined in the backend.
/// The Swift app never calls external APIs directly — all AI and
/// transcription calls go through these edge functions.
class EdgeFunctions {
    static let shared = EdgeFunctions()

    private init() {}

    // MARK: - Response Types

    struct AnalyzeVideoResponse: Codable {
        let inspirationVideoId: String

        enum CodingKeys: String, CodingKey {
            case inspirationVideoId = "inspiration_video_id"
        }
    }

    struct ScoreAlignmentResponse: Codable {
        let score: Int
        let verdict: String
        let reasoning: String
    }

    struct GenerateBriefResponse: Codable {
        let contentBriefId: String

        enum CodingKeys: String, CodingKey {
            case contentBriefId = "content_brief_id"
        }
    }

    struct RunInterviewResponse: Codable {
        let aiMessage: String
        let isComplete: Bool
        let creatorProfileId: String?

        enum CodingKeys: String, CodingKey {
            case aiMessage = "ai_message"
            case isComplete = "is_complete"
            case creatorProfileId = "creator_profile_id"
        }
    }

    struct TranscribeAudioResponse: Codable {
        let transcript: String
        let words: [Word]

        struct Word: Codable {
            let text: String
            let start: Double
            let end: Double
        }
    }

    // MARK: - Edge Function Calls

    /// Analyzes a video URL: transcribes it, scores alignment, and generates a deconstruction.
    func analyzeVideo(url: String, platform: String, creatorProfileId: UUID) async throws -> AnalyzeVideoResponse {
        // TODO: Call supabase.functions.invoke("analyze-video", body: ...)
        fatalError("Not implemented — requires Supabase SDK")
    }

    /// Scores how well an inspiration video aligns with the creator's brand.
    func scoreAlignment(inspirationVideoId: UUID, creatorProfileId: UUID) async throws -> ScoreAlignmentResponse {
        // TODO: Call supabase.functions.invoke("score-alignment", body: ...)
        fatalError("Not implemented — requires Supabase SDK")
    }

    /// Generates a creative brief by remixing the inspiration video with the creator's voice.
    func generateBrief(inspirationVideoId: UUID, creatorProfileId: UUID, userSelections: [String: String]) async throws -> GenerateBriefResponse {
        // TODO: Call supabase.functions.invoke("generate-brief", body: ...)
        fatalError("Not implemented — requires Supabase SDK")
    }

    /// Sends a message in the AI onboarding interview and gets the next response.
    func runInterview(sessionId: UUID, userMessage: String) async throws -> RunInterviewResponse {
        // TODO: Call supabase.functions.invoke("run-interview", body: ...)
        fatalError("Not implemented — requires Supabase SDK")
    }

    /// Transcribes an audio file stored in Supabase Storage.
    func transcribeAudio(audioUrl: String) async throws -> TranscribeAudioResponse {
        // TODO: Call supabase.functions.invoke("transcribe-audio", body: ...)
        fatalError("Not implemented — requires Supabase SDK")
    }
}
