import Photos
import UIKit

/// Handles exporting story assets to the Camera Roll or as shareable files.
/// All methods are async and return a result describing success or failure.
enum AssetExportService {

    enum ExportResult {
        case success
        case permissionDenied
        case fileNotFound
        case failed(String)
    }

    // MARK: - Permission

    /// Requests add-only photo library permission. Returns true if granted.
    static func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }

    // MARK: - Export

    /// Saves an image file to the Camera Roll.
    static func exportImage(at path: String) async -> ExportResult {
        guard FileManager.default.fileExists(atPath: path) else { return .fileNotFound }
        guard await requestPhotoLibraryPermission() else { return .permissionDenied }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let url = URL(fileURLWithPath: path)
                PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: url, options: nil)
            }
            return .success
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Saves a video file to the Camera Roll.
    static func exportVideo(at path: String) async -> ExportResult {
        guard FileManager.default.fileExists(atPath: path) else { return .fileNotFound }
        guard await requestPhotoLibraryPermission() else { return .permissionDenied }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let url = URL(fileURLWithPath: path)
                PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
            }
            return .success
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Saves an audio file to the Camera Roll as a video/audio asset.
    static func exportAudio(at path: String) async -> ExportResult {
        guard FileManager.default.fileExists(atPath: path) else { return .fileNotFound }
        guard await requestPhotoLibraryPermission() else { return .permissionDenied }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let url = URL(fileURLWithPath: path)
                PHAssetCreationRequest.forAsset().addResource(with: .audio, fileURL: url, options: nil)
            }
            return .success
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Creates a temporary .txt file from text content and returns its URL
    /// for sharing via UIActivityViewController.
    static func createTextFile(content: String, name: String?) -> URL? {
        let fileName = (name ?? "text_note") + ".txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }

    /// Exports a single StoryAsset. Returns the result.
    /// For text assets, returns the file URL to share instead of saving to Camera Roll.
    static func export(_ asset: StoryAsset) async -> (result: ExportResult, shareURL: URL?) {
        switch asset.assetType {
        case .image:
            guard let path = asset.fileUrl else { return (.fileNotFound, nil) }
            return (await exportImage(at: path), nil)

        case .video:
            guard let path = asset.fileUrl else { return (.fileNotFound, nil) }
            return (await exportVideo(at: path), nil)

        case .voiceNote:
            guard let path = asset.fileUrl else { return (.fileNotFound, nil) }
            return (await exportAudio(at: path), nil)

        case .text:
            guard let content = asset.contentText, !content.isEmpty else {
                return (.fileNotFound, nil)
            }
            if let url = createTextFile(content: content, name: asset.name) {
                return (.success, url)
            }
            return (.failed("Could not create text file"), nil)
        }
    }
}
