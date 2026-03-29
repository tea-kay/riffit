import AVKit
import SwiftUI

/// Full-screen viewer for a video asset.
/// Shows the video with play controls and an editable title.
struct VideoPlayerView: View {
    let asset: StoryAsset
    @ObservedObject var viewModel: StorybankViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var titleText: String = ""
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            VStack(spacing: RS.lg) {
                // Editable title
                TextField("Video", text: $titleText)
                    .font(RF.heading)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, RS.lg)
                    .padding(.top, RS.lg)

                // Video player — tap play to start, no autoplay
                if let player {
                    VideoPlayer(player: player)
                        .frame(height: 300)
                        .cornerRadius(RR.card)
                        .padding(.horizontal, RS.md)
                } else {
                    // Fallback if video can't be loaded
                    VStack(spacing: RS.sm) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.riffitTextTertiary)

                        Text("Video not found")
                            .font(RF.caption)
                            .foregroundStyle(Color.riffitTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                }

                // Duration
                if let duration = asset.durationSeconds {
                    Text(formatDuration(duration))
                        .font(RF.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.riffitTextSecondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.riffitBackground)
            .navigationTitle("Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        player?.pause()
                        let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            await viewModel.updateAsset(
                                asset,
                                name: trimmed.isEmpty ? nil : trimmed,
                                text: asset.contentText ?? ""
                            )
                        }
                        dismiss()
                    }
                    .font(RF.button)
                    .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .onAppear {
            titleText = asset.name ?? "Video"
            if let path = asset.fileUrl {
                let url = URL(fileURLWithPath: path)
                player = AVPlayer(url: url)
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
