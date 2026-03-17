import SwiftUI

/// Bottom sheet for recording a voice note via press-and-hold.
/// Hold the button to record, release to save. The recording is
/// added to the story as a voice note asset immediately on release.
struct VoiceNoteRecordSheet: View {
    let storyId: UUID
    @ObservedObject var viewModel: StorybankViewModel
    @StateObject private var recorder = AudioRecorderService()
    @Environment(\.dismiss) private var dismiss

    @State private var permissionDenied: Bool = false

    var body: some View {
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
            Text(formatTime(recorder.recordingDuration))
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
                // Pulse animation while recording
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
                            // Finger down — start recording after permission check
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
                            // Finger up — stop and save
                            if recorder.isRecording {
                                if let result = recorder.stopRecording() {
                                    viewModel.addVoiceAsset(
                                        to: storyId,
                                        fileUrl: result.url.path,
                                        durationSeconds: result.durationSeconds
                                    )
                                    dismiss()
                                }
                            }
                        }
                )

            // Cancel button
            Button {
                // Discard any in-progress recording
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
        .background(Color.riffitBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(RR.modal)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let tenths = Int((interval - Double(Int(interval))) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}
