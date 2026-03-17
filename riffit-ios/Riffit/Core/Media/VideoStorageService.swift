import AVFoundation
import UIKit

/// Saves video files to the app's local documents directory and
/// generates thumbnails. Files use UUID names for easy Supabase upload.
enum VideoStorageService {

    /// The directory where videos are stored locally.
    private static var videosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("videos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// The directory where video thumbnails are cached.
    private static var thumbnailsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("video_thumbnails", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Copies a video from a temporary URL to permanent local storage.
    /// Returns the file path, or nil if the copy fails.
    static func save(from temporaryURL: URL) -> String? {
        let fileName = UUID().uuidString + ".mov"
        let destination = videosDirectory.appendingPathComponent(fileName)

        do {
            // Videos from camera/library are in a temp location that gets cleaned up,
            // so we copy rather than move to ensure the file persists
            try FileManager.default.copyItem(at: temporaryURL, to: destination)
            return destination.path
        } catch {
            return nil
        }
    }

    /// Gets the duration of a video file in seconds.
    static func duration(of url: URL) -> Int {
        let asset = AVAsset(url: url)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        return durationSeconds.isNaN ? 0 : Int(durationSeconds)
    }

    /// Generates a thumbnail from the first frame of a video.
    /// Caches it as JPEG and returns the file path.
    static func generateThumbnail(for videoPath: String) -> String? {
        let videoURL = URL(fileURLWithPath: videoPath)
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        // Grab the first frame
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)

        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)

            guard let data = uiImage.jpegData(compressionQuality: 0.7) else { return nil }

            let fileName = UUID().uuidString + ".jpg"
            let thumbURL = thumbnailsDirectory.appendingPathComponent(fileName)
            try data.write(to: thumbURL)
            return thumbURL.path
        } catch {
            return nil
        }
    }

    /// Loads a thumbnail image from a file path.
    static func loadThumbnail(from path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    /// Deletes a video file from local storage.
    static func delete(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
