import UIKit
import Social
import UniformTypeIdentifiers

/// iOS Share Extension entry point.
/// Accepts URLs shared from Safari, Instagram, TikTok, etc.
/// Shows a compose sheet where the user can add a note before saving.
///
/// Note: This uses UIKit (SLComposeServiceViewController) because
/// share extensions require it — there is no SwiftUI equivalent.
/// This is one of the few places UIKit is acceptable per CLAUDE.md.
class ShareViewController: SLComposeServiceViewController {

    /// The URL extracted from the shared content.
    private var sharedURL: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Customize the compose view appearance
        navigationController?.navigationBar.tintColor = UIColor(red: 0.941, green: 0.667, blue: 0.125, alpha: 1.0)
        placeholder = "What caught your eye about this video?"

        extractURL()
    }

    /// Called when the user taps "Post" (the submit button).
    override func didSelectPost() {
        guard let url = sharedURL else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }

        let userNote = contentText ?? ""

        // TODO: Save to Supabase via shared app group or background upload
        // The share extension shares a UserDefaults suite (app group) with the
        // main app. Save the URL + note there, and the main app picks it up
        // on next launch and triggers analysis.
        //
        // let sharedDefaults = UserDefaults(suiteName: "group.com.riffit.app")
        // var pendingShares = sharedDefaults?.array(forKey: "pendingShares") as? [[String: String]] ?? []
        // pendingShares.append(["url": url, "note": userNote])
        // sharedDefaults?.set(pendingShares, forKey: "pendingShares")

        print("[Riffit Share] URL: \(url), Note: \(userNote)")

        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    /// Validates that we have a URL before allowing the user to submit.
    override func isContentValid() -> Bool {
        return sharedURL != nil
    }

    /// Extracts the URL from the shared extension input items.
    private func extractURL() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else { return }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // Check for URLs
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                        if let url = item as? URL {
                            DispatchQueue.main.async {
                                self?.sharedURL = url.absoluteString
                                self?.validateContent()
                            }
                        }
                    }
                    return
                }

                // Check for plain text that might contain a URL
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                        if let text = item as? String,
                           let url = URL(string: text),
                           url.scheme?.hasPrefix("http") == true {
                            DispatchQueue.main.async {
                                self?.sharedURL = text
                                self?.validateContent()
                            }
                        }
                    }
                    return
                }
            }
        }
    }
}
