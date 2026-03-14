import SwiftUI

/// Manages the ideas list: adding new IG links and loading saved ones.
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var videos: [InspirationVideo] = []
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var error: Error?

    var isEmpty: Bool { videos.isEmpty }

    // MARK: - Fetch

    func fetchVideos() async {
        isLoading = true
        error = nil

        // TODO: Fetch from Supabase
        // Start with an empty list — user adds their own ideas
        // videos = try await supabase
        //     .from("inspiration_videos")
        //     .select()
        //     .order("saved_at", ascending: false)
        //     .execute()

        isLoading = false
    }

    // MARK: - Add

    func addVideo(url: String, platform: InspirationVideo.Platform, userNote: String?) async {
        isSubmitting = true

        // TODO: Call analyze-video edge function + save to Supabase

        let newVideo = InspirationVideo(
            id: UUID(),
            creatorProfileId: UUID(),
            url: url,
            platform: platform,
            userNote: userNote,
            thumbnailUrl: nil,
            transcript: nil,
            alignmentScore: nil,
            alignmentVerdict: nil,
            alignmentReasoning: nil,
            status: .pending,
            savedAt: Date()
        )

        videos.insert(newVideo, at: 0)
        isSubmitting = false
    }

    // MARK: - Refresh

    func refresh() async {
        await fetchVideos()
    }
}
