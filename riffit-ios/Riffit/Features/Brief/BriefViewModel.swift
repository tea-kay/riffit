import SwiftUI

/// Manages content brief display and user interactions
/// (selecting sections, viewing shot list).
@MainActor
class BriefViewModel: ObservableObject {
    @Published var briefs: [ContentBrief] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // TODO: Implement brief logic (Phase 4)
}
