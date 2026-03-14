import SwiftUI

/// The Storybank tab — the creator's workspace for organizing stories.
/// Each story collects assets (voice notes, video, images, text) and
/// references to inspiration videos from the Library.
struct StorybankView: View {
    @StateObject private var viewModel = StorybankViewModel()
    @State private var showNewStoryAlert: Bool = false
    @State private var newStoryTitle: String = ""

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
                storyList
            }
        }
        .navigationTitle("Storybank")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newStoryTitle = ""
                    showNewStoryAlert = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .alert("New Story", isPresented: $showNewStoryAlert) {
            TextField("Story title", text: $newStoryTitle)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let trimmed = newStoryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    viewModel.createStory(title: trimmed)
                }
            }
        }
        .task {
            await viewModel.fetchStories()
        }
    }

    // MARK: - Story List

    private var storyList: some View {
        ScrollView {
            LazyVStack(spacing: .smPlus) {
                ForEach(viewModel.stories) { story in
                    NavigationLink(value: story) {
                        StoryCard(story: story, countsLabel: viewModel.countsLabel(for: story.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, .md)
            .padding(.vertical, .smPlus)
        }
        .refreshable {
            await viewModel.fetchStories()
        }
        .navigationDestination(for: Story.self) { story in
            StoryDetailView(story: story, viewModel: viewModel)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: .md) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.riffitPrimary)

            Text("No stories yet")
                .riffitTitle()
                .foregroundStyle(Color.riffitTextPrimary)

            Text("Start your first story to collect\nassets and reference ideas.")
                .riffitBody()
                .foregroundStyle(Color.riffitTextSecondary)
                .multilineTextAlignment(.center)

            RiffitButton(title: "Start Your First Story", variant: .primary) {
                newStoryTitle = ""
                showNewStoryAlert = true
            }
            .padding(.top, .sm)
        }
        .padding(.horizontal, .xl)
    }
}

// MARK: - Story Card

/// A card showing a story in the Storybank list.
struct StoryCard: View {
    let story: Story
    let countsLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: .sm) {
            // Title + status badge
            HStack {
                Text(story.title)
                    .riffitHeading()
                    .foregroundStyle(Color.riffitTextPrimary)
                    .lineLimit(2)

                Spacer()

                StoryStatusBadge(status: story.status)
            }

            // Asset/reference counts
            Text(countsLabel)
                .riffitCaption()
                .foregroundStyle(Color.riffitTextSecondary)

            // Last updated
            Text(story.updatedAt.relativeTimestamp)
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
}

// MARK: - Story Status Badge

/// Capsule badge showing draft/ready status.
struct StoryStatusBadge: View {
    let status: Story.Status

    var body: some View {
        Text(status.label)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(foregroundColor)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch status {
        case .draft:
            return Color.riffitTextSecondary
        case .ready:
            return Color.riffitPrimary
        case .archived:
            return Color.riffitTextTertiary
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .draft:
            return Color.riffitSurface
        case .ready:
            return Color.riffitPrimaryTint
        case .archived:
            return Color.riffitSurface
        }
    }
}

extension Story.Status {
    var label: String {
        switch self {
        case .draft: return "Draft"
        case .ready: return "Ready"
        case .archived: return "Archived"
        }
    }
}
