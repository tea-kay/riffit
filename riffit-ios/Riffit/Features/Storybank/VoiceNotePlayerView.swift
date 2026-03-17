import SwiftUI

/// Full-screen player for a voice note asset.
/// Shows play/pause, progress bar, and duration.
struct VoiceNotePlayerView: View {
    let asset: StoryAsset
    @StateObject private var player = AudioPlayerService()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: RS.xl) {
                Spacer()

                // Waveform icon
                Image(systemName: "waveform")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.riffitTeal400)

                // Asset name
                Text(asset.name ?? "Voice Note")
                    .font(RF.heading)
                    .foregroundStyle(Color.riffitTextPrimary)

                // Time display
                HStack {
                    Text(formatTime(player.currentTime))
                        .font(RF.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.riffitTextSecondary)

                    Spacer()

                    Text(formatTime(player.duration))
                        .font(RF.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.riffitTextTertiary)
                }
                .padding(.horizontal, RS.xl)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(Color.riffitBorderDefault)
                            .frame(height: 4)

                        // Fill
                        let progress = player.duration > 0
                            ? player.currentTime / player.duration
                            : 0
                        Capsule()
                            .fill(Color.riffitTeal400)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, RS.xl)

                // Play/pause button
                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.riffitPrimary)
                }

                Spacer()
            }
            .background(Color.riffitBackground)
            .navigationTitle("Voice Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        player.stop()
                        dismiss()
                    }
                    .font(RF.button)
                    .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .onAppear {
            if let path = asset.fileUrl {
                let url = URL(fileURLWithPath: path)
                player.load(url: url)
            }
        }
        .onDisappear {
            player.stop()
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
