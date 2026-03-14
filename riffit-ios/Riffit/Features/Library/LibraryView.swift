import SwiftUI

/// The main screen — where you submit IG links and see all your saved ideas.
/// Tapping an idea opens the detail view.
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showAddSheet: Bool = false

    var body: some View {
        ZStack {
            Color.riffitBackground
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.isEmpty {
                ProgressView()
                    .tint(Color.riffitPrimary)
            } else if viewModel.isEmpty {
                emptyState
            } else {
                postList
            }
        }
        .navigationTitle("Ideas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddInspirationView(viewModel: viewModel)
        }
        .task {
            await viewModel.fetchVideos()
        }
    }

    // MARK: - Post List

    private var postList: some View {
        ScrollView {
            LazyVStack(spacing: .smPlus) {
                ForEach(viewModel.videos) { video in
                    NavigationLink(value: video) {
                        IdeaRow(video: video)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, .md)
            .padding(.vertical, .smPlus)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .navigationDestination(for: InspirationVideo.self) { video in
            InspirationDetailView(video: video)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: .md) {
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundStyle(Color.riffitPrimary)

            Text("No ideas yet")
                .riffitTitle()
                .foregroundStyle(Color.riffitTextPrimary)

            Text("Found an Instagram reel that sparks something?\nDrop the link here with a quick note.")
                .riffitBody()
                .foregroundStyle(Color.riffitTextSecondary)
                .multilineTextAlignment(.center)

            RiffitButton(title: "Add Your First Idea", variant: .primary) {
                showAddSheet = true
            }
            .padding(.top, .sm)
        }
        .padding(.horizontal, .xl)
    }
}

// MARK: - Idea Row

/// A single row in the ideas list. The note is the headline —
/// it tells you what the idea is about at a glance. URL and
/// timestamp are secondary context.
struct IdeaRow: View {
    let video: InspirationVideo

    var body: some View {
        VStack(alignment: .leading, spacing: .sm) {
            // Note is the primary identifier — what the idea is about
            if let note = video.userNote, !note.isEmpty {
                Text(note)
                    .riffitHeading()
                    .foregroundStyle(Color.riffitTextPrimary)
                    .lineLimit(2)
            } else {
                // Fallback if no note was provided
                Text("No note")
                    .riffitHeading()
                    .foregroundStyle(Color.riffitTextTertiary)
                    .italic()
            }

            // URL shortened to just the path identifier
            HStack(spacing: 6) {
                Image(systemName: "camera")
                    .font(.caption2)
                    .foregroundStyle(Color.riffitTeal400)

                Text(shortURL)
                    .riffitCaption()
                    .foregroundStyle(Color.riffitTextTertiary)
                    .lineLimit(1)
            }

            // Relative timestamp
            Text(video.savedAt, style: .relative)
                .riffitCaption()
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.md)
        .background(Color.riffitSurface)
        .cornerRadius(.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: .cardRadius)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
    }

    /// Strips the URL down to just the meaningful part
    /// e.g. "instagram.com/reel/ABC123" → "reel/ABC123"
    private var shortURL: String {
        guard let url = URL(string: video.url) else { return video.url }
        let path = url.path
        if path.count > 1 {
            // Drop the leading slash
            return String(path.dropFirst())
        }
        return url.host ?? video.url
    }
}

// MARK: - InspirationVideo Hashable (for NavigationLink)

extension InspirationVideo: Hashable {
    static func == (lhs: InspirationVideo, rhs: InspirationVideo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
