import SwiftUI

/// Manages the inspiration video library: fetching, filtering,
/// and triggering analysis of new videos.
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var videos: [InspirationVideo] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // TODO: Implement fetch, filter, and analyze (Phase 3)
}
