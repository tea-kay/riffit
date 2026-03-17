import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Wraps UIImagePickerController for video recording via camera.
struct VideoCameraPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onVideoPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.cameraCaptureMode = .video
        picker.videoMaximumDuration = 60
        picker.videoQuality = .typeMedium
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss, onVideoPicked: onVideoPicked)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let dismiss: DismissAction
        let onVideoPicked: (URL) -> Void

        init(dismiss: DismissAction, onVideoPicked: @escaping (URL) -> Void) {
            self.dismiss = dismiss
            self.onVideoPicked = onVideoPicked
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL {
                onVideoPicked(url)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

/// Wraps PHPickerViewController for selecting a video from the photo library.
/// PHPicker doesn't require full photo library permission.
struct VideoLibraryPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onVideoPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .videos

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss, onVideoPicked: onVideoPicked)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let dismiss: DismissAction
        let onVideoPicked: (URL) -> Void

        init(dismiss: DismissAction, onVideoPicked: @escaping (URL) -> Void) {
            self.dismiss = dismiss
            self.onVideoPicked = onVideoPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            else { return }

            // Load the video file URL — PHPicker gives a temporary file
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, _ in
                guard let tempURL = url else { return }

                // Copy to a temp location we control, because the PHPicker
                // temp file gets deleted when this callback returns
                let tmpDir = FileManager.default.temporaryDirectory
                let copyURL = tmpDir.appendingPathComponent(UUID().uuidString + ".mov")

                do {
                    try FileManager.default.copyItem(at: tempURL, to: copyURL)
                    DispatchQueue.main.async {
                        self?.onVideoPicked(copyURL)
                    }
                } catch {
                    // Copy failed — nothing to do
                }
            }
        }
    }
}
