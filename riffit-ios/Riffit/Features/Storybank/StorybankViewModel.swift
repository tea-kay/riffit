import SwiftUI

/// Manages the StoryBank: fetching entries, creating new ones
/// (manual, voice, AI interview), and tag management.
@MainActor
class StorybankViewModel: ObservableObject {
    @Published var entries: [StoryEntry] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // TODO: Implement storybank logic (Phase 5)
}
