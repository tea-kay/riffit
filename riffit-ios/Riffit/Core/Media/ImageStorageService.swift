import SwiftUI
import UIKit

/// Saves images to the app's local documents directory.
/// Files are saved as JPEG with UUID filenames so they can
/// be uploaded to Supabase Storage later without renaming.
enum ImageStorageService {

    /// The directory where images are stored locally.
    private static var imagesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("images", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Saves a UIImage to local storage and returns the file path.
    /// Returns nil if the save fails.
    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            return nil
        }
    }

    /// Loads an image from a local file path.
    static func load(from path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    /// Deletes an image file from local storage.
    static func delete(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
