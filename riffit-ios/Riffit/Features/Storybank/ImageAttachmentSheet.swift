import SwiftUI
import AVFoundation

/// Sheet for adding an image asset to a story.
/// Step 1: Pick source (camera or photo library)
/// Step 2: Preview the image with an editable title, then save or discard
struct ImageAttachmentSheet: View {
    let storyId: UUID
    @ObservedObject var viewModel: StorybankViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showSourcePicker: Bool = true
    @State private var showCamera: Bool = false
    @State private var showPhotoLibrary: Bool = false
    @State private var selectedImage: UIImage?
    @State private var imageName: String = ""
    @State private var showCameraPermissionAlert: Bool = false

    var body: some View {
        Group {
            if let image = selectedImage {
                previewScreen(image: image)
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
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { image in
                handleImagePicked(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoLibraryPickerView { image in
                handleImagePicked(image)
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
            Text("Riffit needs camera access to take photos. Enable it in Settings.")
        }
    }

    // MARK: - Source Picker

    private var sourcePickerScreen: some View {
        VStack(spacing: RS.lg) {
            // Drag handle
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, RS.smPlus)

            Text("Add Image")
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)

            Spacer()

            // Source options
            VStack(spacing: RS.smPlus) {
                Button {
                    checkCameraPermissionAndOpen()
                } label: {
                    HStack(spacing: RS.smPlus) {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .foregroundStyle(Color.riffitPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.riffitPrimaryTint)
                            .cornerRadius(RR.button)

                        Text("Take Photo")
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

                Button {
                    showPhotoLibrary = true
                } label: {
                    HStack(spacing: RS.smPlus) {
                        Image(systemName: "photo.on.rectangle")
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

            // Cancel
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

    private func previewScreen(image: UIImage) -> some View {
        VStack(spacing: RS.lg) {
            // Drag handle
            Capsule()
                .fill(Color.riffitTextTertiary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, RS.smPlus)

            Text("Save Image")
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)

            // Editable title
            TextField("Image", text: $imageName)
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

            // Image preview
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(RR.card)
                .padding(.horizontal, RS.md)

            Spacer()

            // Save button
            RiffitButton(title: "Save", variant: .primary) {
                saveImage(image)
            }
            .padding(.horizontal, RS.md)

            // Discard
            Button {
                selectedImage = nil
            } label: {
                Text("Discard")
                    .font(RF.button)
                    .foregroundStyle(Color.riffitTextSecondary)
            }
            .padding(.bottom, RS.lg)
        }
    }

    // MARK: - Helpers

    private func handleImagePicked(_ image: UIImage) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        imageName = "Image — \(formatter.string(from: Date()))"
        selectedImage = image
    }

    private func checkCameraPermissionAndOpen() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        showCameraPermissionAlert = true
                    }
                }
            }
        default:
            showCameraPermissionAlert = true
        }
    }

    private func saveImage(_ image: UIImage) {
        guard let filePath = ImageStorageService.save(image) else { return }

        let trimmedName = imageName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await viewModel.addImageAsset(
                to: storyId,
                fileUrl: filePath,
                name: trimmedName.isEmpty ? nil : trimmedName
            )
        }
        dismiss()
    }
}
