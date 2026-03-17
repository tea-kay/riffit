import AVKit
import SwiftUI
import AVFoundation

/// Sheet for adding a video asset to a story.
/// Step 1: Pick source (record or choose from library)
/// Step 2: Preview video with editable title, then save or discard
struct VideoAttachmentSheet: View {
    let storyId: UUID
    @ObservedObject var viewModel: StorybankViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showVideoCamera: Bool = false
    @State private var showVideoLibrary: Bool = false
    @State private var selectedVideoURL: URL?
    @State private var videoName: String = ""
    @State private var showCameraPermissionAlert: Bool = false

    /// Whether the device has a camera available
    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Group {
            if let videoURL = selectedVideoURL {
                previewScreen(videoURL: videoURL)
            } else {
                sourcePickerScreen
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.riffitBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(RR.modal)
        .presentationBackground(Color.riffitBackground)
        .fullScreenCover(isPresented: $showVideoCamera) {
            VideoCameraPickerView { url in
                handleVideoPicked(url)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showVideoLibrary) {
            VideoLibraryPickerView { url in
                handleVideoPicked(url)
            }
        }
        .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Riffit needs camera access to record video. Enable it in Settings.")
        }
    }

    // MARK: - Source Picker

    private var sourcePickerScreen: some View {
        VStack(spacing: RS.lg) {
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, RS.smPlus)

            Text("Add Video")
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)

            Spacer()

            VStack(spacing: RS.smPlus) {
                // Record option — always visible, disabled if no camera
                Button {
                    checkCameraPermissionAndOpen()
                } label: {
                    HStack(spacing: RS.smPlus) {
                        Image(systemName: "video.fill")
                            .font(.title3)
                            .foregroundStyle(cameraAvailable ? Color.riffitPrimary : Color.riffitTextTertiary)
                            .frame(width: 44, height: 44)
                            .background(cameraAvailable ? Color.riffitPrimaryTint : Color.riffitSurface)
                            .cornerRadius(RR.button)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Record Video")
                                .font(RF.button)
                                .foregroundStyle(cameraAvailable ? Color.riffitTextPrimary : Color.riffitTextTertiary)

                            if !cameraAvailable {
                                Text("Camera not available")
                                    .font(RF.meta)
                                    .foregroundStyle(Color.riffitTextTertiary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.riffitTextTertiary)
                    }
                    .padding(RS.md)
                    .background(Color.riffitSurface)
                    .cornerRadius(RR.input)
                    .overlay(
                        RoundedRectangle(cornerRadius: RR.input)
                            .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!cameraAvailable)

                // Library option
                Button {
                    showVideoLibrary = true
                } label: {
                    HStack(spacing: RS.smPlus) {
                        Image(systemName: "film")
                            .font(.title3)
                            .foregroundStyle(Color.riffitTeal400)
                            .frame(width: 44, height: 44)
                            .background(Color.riffitTealTint)
                            .cornerRadius(RR.button)

                        Text("Choose from Library")
                            .font(RF.button)
                            .foregroundStyle(Color.riffitTextPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.riffitTextTertiary)
                    }
                    .padding(RS.md)
                    .background(Color.riffitSurface)
                    .cornerRadius(RR.input)
                    .overlay(
                        RoundedRectangle(cornerRadius: RR.input)
                            .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, RS.md)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(RF.button)
                    .foregroundStyle(Color.riffitTextSecondary)
            }
            .padding(.bottom, RS.lg)
        }
    }

    // MARK: - Preview Screen

    private func previewScreen(videoURL: URL) -> some View {
        VStack(spacing: RS.lg) {
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, RS.smPlus)

            Text("Save Video")
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)

            // Editable title
            TextField("Video", text: $videoName)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextPrimary)
                .padding(RS.smPlus)
                .background(Color.riffitSurface)
                .cornerRadius(RR.input)
                .overlay(
                    RoundedRectangle(cornerRadius: RR.input)
                        .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                )
                .padding(.horizontal, RS.md)

            // Video player preview — does NOT autoplay (respects user)
            VideoPlayer(player: AVPlayer(url: videoURL))
                .frame(height: 240)
                .cornerRadius(RR.card)
                .padding(.horizontal, RS.md)

            // Duration label
            let duration = VideoStorageService.duration(of: videoURL)
            Text(formatDuration(duration))
                .font(RF.caption)
                .monospacedDigit()
                .foregroundStyle(Color.riffitTextSecondary)

            Spacer()

            // Save
            RiffitButton(title: "Save", variant: .primary) {
                saveVideo(from: videoURL)
            }
            .padding(.horizontal, RS.md)

            // Discard
            Button {
                selectedVideoURL = nil
            } label: {
                Text("Discard")
                    .font(RF.button)
                    .foregroundStyle(Color.riffitTextSecondary)
            }
            .padding(.bottom, RS.lg)
        }
    }

    // MARK: - Helpers

    private func handleVideoPicked(_ url: URL) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        videoName = "Video — \(formatter.string(from: Date()))"
        selectedVideoURL = url
    }

    private func checkCameraPermissionAndOpen() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showVideoCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showVideoCamera = true
                    } else {
                        showCameraPermissionAlert = true
                    }
                }
            }
        default:
            showCameraPermissionAlert = true
        }
    }

    private func saveVideo(from tempURL: URL) {
        guard let filePath = VideoStorageService.save(from: tempURL) else { return }

        let duration = VideoStorageService.duration(of: URL(fileURLWithPath: filePath))
        let trimmedName = videoName.trimmingCharacters(in: .whitespacesAndNewlines)

        viewModel.addVideoAsset(
            to: storyId,
            fileUrl: filePath,
            durationSeconds: duration,
            name: trimmedName.isEmpty ? nil : trimmedName
        )
        dismiss()
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
