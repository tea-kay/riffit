import SwiftUI

/// Bottom sheet for recording a voice note via press-and-hold.
/// After recording, shows a preview screen where the user can
/// edit the title, play back, and save.
struct VoiceNoteRecordSheet: View {
    let storyId: UUID
    @ObservedObject var viewModel: StorybankViewModel
    @StateObject private var recorder = AudioRecorderService()
    @StateObject private var player = AudioPlayerService()
    @Environment(\.dismiss) private var dismiss

    @State private var permissionDenied: Bool = false
    @State private var recordingResult: (url: URL, durationSeconds: Int)?
    @State private var noteName: String = ""

    /// Whether we're on the preview screen (after recording finishes)
    private var isPreview: Bool { recordingResult != nil }

    var body: some View {
        Group {
            if isPreview {
                previewScreen
            } else {
                recordScreen
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.riffitBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(RR.modal)
        .presentationBackground(Color.riffitBackground)
    }

    // MARK: - Record Screen

    private var recordScreen: some View {
        VStack(spacing: RS.lg) {
            // Drag handle
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, RS.smPlus)

            Text("Voice Note")
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)

            Spacer()

            // Duration display
            Text(formatRecordingTime(recorder.recordingDuration))
                .font(RF.display(48))
                .foregroundStyle(recorder.isRecording ? Color.riffitPrimary : Color.riffitTextTertiary)
                .monospacedDigit()

            // Recording hint
            Text(recorder.isRecording ? "Recording..." : "Hold to record")
                .font(RF.caption)
                .foregroundStyle(recorder.isRecording ? Color.riffitPrimary : Color.riffitTextSecondary)

            Spacer()

            if permissionDenied {
                Text("Microphone access is required. Enable it in Settings.")
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, RS.lg)
            }

            // Press-and-hold record button
            Circle()
                .fill(recorder.isRecording ? Color.riffitDanger : Color.riffitPrimary)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.title)
                        .foregroundStyle(Color.riffitOnPrimary)
                )
                .scaleEffect(recorder.isRecording ? 1.1 : 1.0)
                .animation(
                    recorder.isRecording
                        ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                        : .default,
                    value: recorder.isRecording
                )
                .gesture(
                    LongPressGesture(minimumDuration: 0.15)
                        .onChanged { _ in
                            if !recorder.isRecording {
                                Task {
                                    let granted = await recorder.requestPermission()
                                    if granted {
                                        permissionDenied = false
                                        recorder.startRecording()
                                    } else {
                                        permissionDenied = true
                                    }
                                }
                            }
                        }
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onEnded { _ in
                            if recorder.isRecording {
                                if let result = recorder.stopRecording() {
                                    // Generate default title with timestamp
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "MMM d, yyyy"
                                    noteName = "Voice Note — \(formatter.string(from: Date()))"

                                    recordingResult = result

                                    // Load for playback preview
                                    player.load(url: result.url)
                                }
                            }
                        }
                )

            // Cancel button
            Button {
                if recorder.isRecording {
                    if let result = recorder.stopRecording() {
                        AudioRecorderService.deleteFile(at: result.url)
                    }
                }
                dismiss()
            } label: {
                Text("Cancel")
                    .font(RF.button)
                    .foregroundStyle(Color.riffitTextSecondary)
            }
            .padding(.bottom, RS.lg)
        }
        .padding(.horizontal, RS.md)
    }

    // MARK: - Preview Screen (after recording)

    private var previewScreen: some View {
        VStack(spacing: RS.lg) {
            // Drag handle
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, RS.smPlus)

            Text("Save Voice Note")
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)

            // Editable title field
            TextField("Voice Note", text: $noteName)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextPrimary)
                .padding(RS.smPlus)
                .background(Color.riffitSurface)
                .cornerRadius(RR.input)
                .overlay(
                    RoundedRectangle(cornerRadius: RR.input)
                        .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                )

            Spacer()

            // Waveform icon
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(Color.riffitTeal400)

            // Duration
            if let result = recordingResult {
                Text(formatPlaybackTime(result.durationSeconds))
                    .font(RF.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color.riffitTextSecondary)
            }

            // Play/pause preview
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.riffitPrimary)
            }

            Spacer()

            // Save button
            RiffitButton(title: "Save", variant: .primary) {
                if let result = recordingResult {
                    let trimmedName = noteName.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        await viewModel.addVoiceAsset(
                            to: storyId,
                            fileUrl: result.url.path,
                            durationSeconds: result.durationSeconds,
                            name: trimmedName.isEmpty ? nil : trimmedName
                        )
                    }
                    player.stop()
                    dismiss()
                }
            }

            // Discard button
            Button {
                if let result = recordingResult {
                    player.stop()
                    AudioRecorderService.deleteFile(at: result.url)
                }
                dismiss()
            } label: {
                Text("Discard")
                    .font(RF.button)
                    .foregroundStyle(Color.riffitTextSecondary)
            }
            .padding(.bottom, RS.lg)
        }
        .padding(.horizontal, RS.md)
    }

    // MARK: - Formatting

    private func formatRecordingTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let tenths = Int((interval - Double(Int(interval))) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    private func formatPlaybackTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
