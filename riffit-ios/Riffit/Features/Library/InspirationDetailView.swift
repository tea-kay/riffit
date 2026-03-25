import SwiftUI
import WebKit

/// Detail view shown when tapping an idea row.
/// Displays the video, tags, alignment data, transcript, and a
/// chat-style comment thread with an input bar pinned at the bottom.
struct InspirationDetailView: View {
    let video: InspirationVideo
    @ObservedObject var viewModel: LibraryViewModel
    @EnvironmentObject var storybankViewModel: StorybankViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm: Bool = false

    @EnvironmentObject var appState: AppState

    /// Display name for note bubbles: username > full_name > email prefix
    private var displayName: String {
        if let username = appState.currentUser?.username?.trimmingCharacters(in: .whitespacesAndNewlines),
           !username.isEmpty {
            return username
        }
        if let name = appState.currentUser?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        if let email = appState.currentUser?.email {
            return email.components(separatedBy: "@").first ?? "You"
        }
        return "You"
    }

    /// Initials from the authenticated user for avatar fallback
    private var avatarInitial: String {
        if let name = appState.currentUser?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            let parts = name.split(separator: " ")
            if parts.count >= 2,
               let first = parts.first?.first,
               let last = parts.last?.first {
                return "\(first)\(last)".uppercased()
            }
            if let first = parts.first?.first {
                return String(first).uppercased()
            }
        }
        if let first = appState.currentUser?.email.first {
            return String(first).uppercased()
        }
        return "?"
    }

    @State private var showFullTranscript: Bool = false
    @State private var newCommentText: String = ""
    @State private var showNewTagField: Bool = false
    @State private var newTagText: String = ""
    @State private var titleText: String = ""
    @State private var editingCommentId: UUID?
    @State private var editingCommentText: String = ""
    @FocusState private var isCommentFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: RS.lg) {
                        // Editable title
                        TextField("Add a title...", text: $titleText)
                            .font(RF.heading)
                            .foregroundStyle(Color.riffitTextPrimary)
                            .onChange(of: titleText) { newValue in
                                viewModel.updateTitle(for: video.id, title: newValue)
                            }

                        // Embedded video webview
                        videoPlayer

                        // Tags — tap to toggle, + to create custom
                        tagsSection

                        // Transcript section
                        if let transcript = video.transcript, !transcript.isEmpty {
                            transcriptSection(transcript)
                        }

                        // Comments thread
                        commentsSection

                        // Invisible anchor to scroll to bottom
                        Color.clear
                            .frame(height: 1)
                            .id("commentsBottom")
                    }
                    .padding(RS.md)
                }
                .onChange(of: viewModel.comments(for: video.id).count) { _ in
                    withAnimation {
                        proxy.scrollTo("commentsBottom", anchor: .bottom)
                    }
                }
            }

            // Comment input bar — pinned at bottom, outside ScrollView
            commentInputBar
        }
        .background(Color.riffitBackground)
        .navigationTitle(video.platform.displayLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Idea", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .alert("Delete this idea?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                storybankViewModel.removeReferences(for: video.id)
                viewModel.deleteVideo(video.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .onAppear {
            titleText = video.title ?? ""
        }
    }

    // MARK: - Video Player

    @ViewBuilder
    private var videoPlayer: some View {
        if video.platform == .youtube {
            youtubeThumbnailPlayer
        } else if video.platform == .x {
            xPostPlayer
        } else if video.platform == .tiktok {
            // TikTok uses a vertical 9:16 embed
            VideoWebView(url: PlatformDetector.tiktokEmbedUrl(from: video.url))
                .aspectRatio(9/16, contentMode: .fit)
                .cornerRadius(RR.card)
                .overlay(
                    RoundedRectangle(cornerRadius: RR.card)
                        .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
                )
        } else {
            VideoWebView(url: video.url)
                .frame(height: 280)
                .cornerRadius(RR.card)
                .overlay(
                    RoundedRectangle(cornerRadius: RR.card)
                        .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
                )
        }
    }

    /// YouTube videos show a thumbnail with a play overlay.
    /// Tapping opens the YouTube app (youtube:// scheme) or
    /// falls back to Safari if the app isn't installed.
    private var youtubeThumbnailPlayer: some View {
        VStack(spacing: RS.sm) {
            Button {
                openYouTubeVideo()
            } label: {
                ZStack {
                    // Thumbnail or teal placeholder
                    if let thumbUrl = video.thumbnailUrl,
                       let url = URL(string: thumbUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        } placeholder: {
                            Color.riffitSurface
                                .aspectRatio(16/9, contentMode: .fill)
                        }
                    } else {
                        // Fallback when no thumbnail — dark surface with icon
                        Color.riffitSurface
                            .aspectRatio(16/9, contentMode: .fill)
                            .overlay(
                                Image(systemName: "play.rectangle")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.riffitTextTertiary)
                            )
                    }

                    // Play button overlay
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.9))
                                .offset(x: 2) // optical centering
                        )
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: RR.card))
                .overlay(
                    RoundedRectangle(cornerRadius: RR.card)
                        .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            Text("Watch on YouTube")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextSecondary)
        }
    }

    /// Opens the YouTube app via deep link, falls back to Safari.
    private func openYouTubeVideo() {
        guard let videoId = PlatformDetector.youtubeVideoId(from: video.url) else {
            // No video ID — open the raw URL in Safari
            if let url = URL(string: video.url) {
                UIApplication.shared.open(url)
            }
            return
        }

        // Try the YouTube app first
        let appUrl = URL(string: "youtube://\(videoId)")
        let webUrl = URL(string: "https://www.youtube.com/watch?v=\(videoId)")

        if let appUrl, UIApplication.shared.canOpenURL(appUrl) {
            UIApplication.shared.open(appUrl)
        } else if let webUrl {
            UIApplication.shared.open(webUrl)
        }
    }

    // MARK: - X Post Player

    /// X blocks webview embeds entirely. Show a thumbnail if available,
    /// or a styled placeholder for text-only posts. Tap opens the X app
    /// or Safari.
    private var xPostPlayer: some View {
        VStack(spacing: RS.sm) {
            Button {
                PlatformDetector.openXPost(urlString: video.url)
            } label: {
                if let thumbUrl = video.thumbnailUrl,
                   let url = URL(string: thumbUrl) {
                    // Thumbnail from og:image
                    ZStack {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.riffitSurface
                        }

                        // Subtle open indicator
                        Image(systemName: "arrow.up.right.square")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(RS.sm)
                            .background(.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: RR.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: RR.card)
                            .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
                    )
                } else {
                    // No thumbnail — styled placeholder for text posts
                    VStack(spacing: RS.smPlus) {
                        Image(systemName: "at")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.riffitTextTertiary)

                        Text("Tap to view post")
                            .font(RF.caption)
                            .foregroundStyle(Color.riffitTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color.riffitSurface)
                    .clipShape(RoundedRectangle(cornerRadius: RR.card))
                    .overlay(
                        RoundedRectangle(cornerRadius: RR.card)
                            .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
                    )
                }
            }
            .buttonStyle(.plain)

            Text("View on X")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextSecondary)
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        let activeTags = viewModel.tags(for: video.id)

        return VStack(alignment: .leading, spacing: RS.sm) {
            Text("Tags")
                .font(RF.label)
                .textCase(.uppercase)
                .tracking(0.08 * 13)
                .foregroundStyle(Color.riffitTextTertiary)

            // Wrapping flow of tag pills — all available tags shown,
            // selected ones highlighted, tap to toggle
            FlowLayout(spacing: 6) {
                ForEach(viewModel.allTags, id: \.self) { tag in
                    let isSelected = activeTags.contains(tag)
                    Button {
                        viewModel.toggleTag(for: video.id, tag: tag)
                    } label: {
                        Text(tag)
                            .font(RF.tag)
                            .foregroundStyle(isSelected ? Color.riffitOnPrimary : Color.riffitTextSecondary)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(isSelected ? Color.riffitPrimary : Color.riffitSurface)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : Color.riffitBorderDefault, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }

                // "+" button to create a new custom tag
                if showNewTagField {
                    HStack(spacing: RS.xs) {
                        TextField("New tag", text: $newTagText)
                            .font(RF.tag)
                            .foregroundStyle(Color.riffitTextPrimary)
                            .frame(width: 80)
                            .onSubmit {
                                submitNewTag()
                            }

                        Button {
                            submitNewTag()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.callout)
                                .foregroundStyle(Color.riffitPrimary)
                        }
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color.riffitSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                    )
                } else {
                    Button {
                        showNewTagField = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundStyle(Color.riffitTextTertiary)
                            .frame(width: 28, height: 28)
                            .background(Color.riffitSurface)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func submitNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            viewModel.addCustomTag(trimmed)
            // Auto-select the new tag on this video
            viewModel.toggleTag(for: video.id, tag: trimmed)
        }
        newTagText = ""
        showNewTagField = false
    }

    // MARK: - Transcript Section

    private func transcriptSection(_ transcript: String) -> some View {
        VStack(alignment: .leading, spacing: RS.smPlus) {
            Text("Transcript")
                .font(RF.label)
                .textCase(.uppercase)
                .tracking(0.08 * 13)
                .foregroundStyle(Color.riffitTextTertiary)

            VStack(alignment: .leading, spacing: RS.sm) {
                Text(transcript)
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextSecondary)
                    .lineLimit(showFullTranscript ? nil : 6)

                if transcript.count > 200 {
                    Button(showFullTranscript ? "Show less" : "Show full transcript") {
                        withAnimation {
                            showFullTranscript.toggle()
                        }
                    }
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTeal400)
                }
            }
            .riffitCard()
        }
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        let comments = viewModel.comments(for: video.id)

        return VStack(alignment: .leading, spacing: RS.smPlus) {
            Text("Notes")
                .font(RF.label)
                .textCase(.uppercase)
                .tracking(0.08 * 13)
                .foregroundStyle(Color.riffitTextTertiary)

            if comments.isEmpty {
                emptyCommentsState
            } else {
                ForEach(comments) { comment in
                    CommentBubble(
                        comment: comment,
                        displayName: displayName,
                        initial: avatarInitial,
                        avatarUrl: appState.currentUser?.avatarUrl,
                        isEditing: editingCommentId == comment.id,
                        editText: editingCommentId == comment.id ? $editingCommentText : .constant(""),
                        onTap: {
                            editingCommentId = comment.id
                            editingCommentText = comment.text
                        },
                        onSave: {
                            let trimmed = editingCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                viewModel.updateComment(id: comment.id, videoId: video.id, newText: trimmed)
                            }
                            editingCommentId = nil
                        },
                        onCancel: {
                            editingCommentId = nil
                        }
                    )
                }
            }
        }
    }

    private var emptyCommentsState: some View {
        VStack(spacing: RS.sm) {
            Text("No notes yet")
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextTertiary)

            Text("Add your first thought below.")
                .font(RF.caption)
                .foregroundStyle(Color.riffitTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RS.lg)
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        HStack(alignment: .bottom, spacing: RS.smPlus) {
            TextField("Add a note...", text: $newCommentText, axis: .vertical)
                .lineLimit(1...5)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextPrimary)
                .focused($isCommentFieldFocused)

            Button {
                sendComment()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(
                        canSend ? Color.riffitPrimary : Color.riffitTextTertiary
                    )
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, RS.md)
        .padding(.vertical, RS.smPlus)
        .background(Color.riffitSurface)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.riffitBorderSubtle),
            alignment: .top
        )
    }

    private var canSend: Bool {
        !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendComment() {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        viewModel.addComment(to: video.id, text: trimmed, authorName: displayName)
        newCommentText = ""
    }
}

// MARK: - Comment Bubble

/// A single comment in the thread with avatar + content layout.
/// Tap to enter inline edit mode — text becomes a TextEditor.
struct CommentBubble: View {
    let comment: IdeaComment
    let displayName: String
    let initial: String
    let avatarUrl: String?
    let isEditing: Bool
    @Binding var editText: String
    let onTap: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: RS.sm) {
            // Avatar — 28×28 circle, leading, top-aligned
            if let urlString = avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    commentInitialsCircle
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            } else {
                commentInitialsCircle
            }

            // Content
            VStack(alignment: .leading, spacing: RS.xs) {
                // Author row: name · time ago  |  or  Save/Cancel when editing
                HStack {
                    HStack(spacing: 0) {
                        Text(displayName)
                            .font(RF.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.riffitTextPrimary)

                        if !isEditing {
                            Text(" · \(comment.createdAt.relativeTimestamp)")
                                .font(RF.meta)
                                .foregroundStyle(Color.riffitTextTertiary)
                        }
                    }

                    Spacer()

                    if isEditing {
                        Button {
                            onCancel()
                        } label: {
                            Text("Cancel")
                                .font(RF.caption)
                                .foregroundStyle(Color.riffitTextTertiary)
                        }

                        Button {
                            onSave()
                        } label: {
                            Text("Save")
                                .font(RF.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.riffitPrimary)
                        }
                    }
                }

                // Note text or inline editor
                if isEditing {
                    TextEditor(text: $editText)
                        .font(RF.bodyMd)
                        .foregroundStyle(Color.riffitTextPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 40)
                } else {
                    Text(comment.text)
                        .font(RF.bodyMd)
                        .foregroundStyle(Color.riffitTextSecondary)
                }
            }
        }
        .padding(RS.smPlus)
        .background(isEditing ? Color.riffitElevated : Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(isEditing ? Color.riffitPrimary.opacity(0.5) : Color.riffitBorderSubtle, lineWidth: isEditing ? 1 : 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                onTap()
            }
        }
    }

    /// Initials circle fallback for when no avatar URL is available
    private var commentInitialsCircle: some View {
        Text(initial)
            .font(RF.caption)
            .foregroundStyle(Color.riffitTextPrimary)
            .frame(width: 28, height: 28)
            .background(Color.riffitTeal600)
            .clipShape(Circle())
    }
}

// MARK: - Relative Timestamp

extension Date {
    /// Formats a date as a relative timestamp like "2m ago", "1h ago", "Yesterday".
    var relativeTimestamp: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 172800 {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: self)
        }
    }
}

// MARK: - Video Web View

/// A WKWebView wrapper for playing videos from social platforms.
/// SwiftUI doesn't have a native webview, so we use UIViewRepresentable
/// to bridge UIKit's WKWebView into SwiftUI.
struct VideoWebView: UIViewRepresentable {
    let url: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        // Allow media to autoplay without user gesture
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let videoURL = URL(string: url) {
            let request = URLRequest(url: videoURL)
            webView.load(request)
        }
    }
}
