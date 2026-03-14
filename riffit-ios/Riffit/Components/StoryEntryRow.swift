import SwiftUI

/// Reusable row component for displaying a story entry in the StoryBank list.
/// Shows a teal icon, title, body preview, and category tag.
struct StoryEntryRow: View {
    let entry: StoryEntry

    var body: some View {
        // TODO: Implement row layout (Phase 5, Step 20)
        Text(entry.title)
            .riffitRow()
    }
}
