import Foundation
import UIKit

/// Detects social platform from a URL string and extracts platform-specific
/// metadata like YouTube video IDs. Keep all URL parsing logic here —
/// never in View bodies.
enum PlatformDetector {

    /// Detects which platform a URL belongs to. Returns nil if unrecognized.
    static func detect(from urlString: String) -> InspirationVideo.Platform? {
        let lowered = urlString.lowercased()

        if lowered.contains("instagram.com") || lowered.contains("instagr.am") {
            return .instagram
        }
        if lowered.contains("youtube.com") || lowered.contains("youtu.be") {
            return .youtube
        }
        if lowered.contains("tiktok.com") {
            return .tiktok
        }
        if lowered.contains("linkedin.com") {
            return .linkedin
        }
        if lowered.contains("x.com") || lowered.contains("twitter.com") {
            return .x
        }

        return nil
    }

    /// Returns true if the URL belongs to any supported platform.
    static func isSupported(_ urlString: String) -> Bool {
        detect(from: urlString) != nil
    }

    /// Extracts the YouTube video ID from a URL string.
    /// Handles three formats:
    ///   - youtube.com/watch?v=VIDEO_ID
    ///   - youtu.be/VIDEO_ID
    ///   - youtube.com/shorts/VIDEO_ID
    /// Returns nil if the URL isn't a recognized YouTube format.
    static func youtubeVideoId(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let host = url.host?.lowercased() ?? ""

        // youtu.be/VIDEO_ID — the path IS the video ID (after the leading /)
        if host.contains("youtu.be") {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? nil : path
        }

        // youtube.com/shorts/VIDEO_ID — video ID is the last path component
        if host.contains("youtube.com"), url.path.lowercased().hasPrefix("/shorts/") {
            let components = url.path.split(separator: "/")
            if components.count >= 2 {
                return String(components[1])
            }
        }

        // youtube.com/watch?v=VIDEO_ID — video ID is the "v" query parameter
        if host.contains("youtube.com") {
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            return queryItems?.first(where: { $0.name == "v" })?.value
        }

        return nil
    }

    /// Returns the YouTube embed URL for playback in a WKWebView.
    /// Falls back to the original URL if video ID can't be extracted.
    static func youtubeEmbedUrl(from urlString: String) -> String {
        if let videoId = youtubeVideoId(from: urlString) {
            return "https://www.youtube.com/embed/\(videoId)"
        }
        return urlString
    }

    /// Extracts the TikTok video ID from a URL string.
    /// TikTok URLs follow: tiktok.com/@username/video/VIDEO_ID
    /// The video ID is the numeric path component after "/video/".
    /// Returns nil if the URL doesn't match or has no numeric ID.
    static func tiktokVideoId(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased(),
              host.contains("tiktok.com")
        else { return nil }

        let components = url.path.split(separator: "/")
        // Look for "video" followed by a numeric ID
        for (index, component) in components.enumerated() {
            if component == "video", index + 1 < components.count {
                let videoId = String(components[index + 1])
                // TikTok video IDs are numeric — validate loosely
                if videoId.allSatisfy(\.isNumber), !videoId.isEmpty {
                    return videoId
                }
            }
        }
        return nil
    }

    /// Returns the TikTok embed URL for playback in a WKWebView.
    /// Falls back to the original URL if video ID can't be extracted.
    static func tiktokEmbedUrl(from urlString: String) -> String {
        if let videoId = tiktokVideoId(from: urlString) {
            return "https://www.tiktok.com/embed/\(videoId)"
        }
        return urlString
    }

    /// Opens an X/Twitter post in the X app or falls back to Safari.
    /// Tries twitter:// deep link first (works for both X and legacy Twitter app),
    /// then falls back to the https URL.
    static func openXPost(urlString: String) {
        guard let url = URL(string: urlString) else { return }

        // Normalize to x.com for the web fallback
        let webUrlString = urlString
            .replacingOccurrences(of: "twitter.com", with: "x.com")

        // Try the X app via twitter:// scheme
        // Convert https://x.com/user/status/123 → twitter://status?id=123
        if let statusId = xStatusId(from: urlString) {
            let appUrl = URL(string: "twitter://status?id=\(statusId)")
            if let appUrl, UIApplication.shared.canOpenURL(appUrl) {
                UIApplication.shared.open(appUrl)
                return
            }
        }

        // Fall back to Safari
        if let webUrl = URL(string: webUrlString) {
            UIApplication.shared.open(webUrl)
        } else {
            UIApplication.shared.open(url)
        }
    }

    /// Extracts the status/post ID from an X or Twitter URL.
    /// Handles: x.com/user/status/ID and twitter.com/user/status/ID
    static func xStatusId(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let components = url.path.split(separator: "/")
        // Look for "status" followed by a numeric ID
        for (index, component) in components.enumerated() {
            if component == "status", index + 1 < components.count {
                let statusId = String(components[index + 1])
                if !statusId.isEmpty {
                    return statusId
                }
            }
        }
        return nil
    }

    /// The SF Symbol icon name for each platform.
    static func icon(for platform: InspirationVideo.Platform) -> String {
        switch platform {
        case .instagram: return "camera"
        case .youtube:   return "play.rectangle"
        case .tiktok:    return "music.note"
        case .linkedin:  return "briefcase"
        case .x:         return "at"
        }
    }

    /// The placeholder text for the URL field based on detected platform.
    static func urlPlaceholder(for platform: InspirationVideo.Platform?) -> String {
        switch platform {
        case .instagram: return "Paste an Instagram link..."
        case .youtube:   return "Paste a YouTube link..."
        case .tiktok:    return "Paste a TikTok link..."
        case .linkedin:  return "Paste a LinkedIn link..."
        case .x:         return "Paste an X link..."
        case nil:        return "Paste a video link..."
        }
    }
}
