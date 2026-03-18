import SwiftUI
import UIKit

/// Wraps UIActivityViewController for sharing files/content.
/// SwiftUI doesn't have a native share sheet, so we bridge via
/// UIViewControllerRepresentable.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
