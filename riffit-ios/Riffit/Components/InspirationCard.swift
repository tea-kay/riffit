import SwiftUI

/// Reusable card component for displaying an inspiration video
/// in the library feed. Shows platform, title, user note,
/// alignment badge and score.
struct InspirationCard: View {
    let video: InspirationVideo

    var body: some View {
        // TODO: Implement card layout (Phase 3, Step 15)
        Text(video.url)
            .riffitCard()
    }
}
