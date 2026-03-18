import SwiftUI
import WebKit

/// Detail view shown when tapping an idea row.
/// Displays the video, tags, alignment data, transcript, and a
/// chat-style comment thread with an input bar pinned at the bottom.
struct InspirationDetailView: View {
    let video: InspirationVideo
    @ObservedObject var viewModel: LibraryViewModel

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
        .onAppear {
            titleText = video.title ?? ""
        }
    }

    // MARK: - Video Player

    private var videoPlayer: some View {
        VideoWebView(url: video.url)
            .frame(height: 280)
            .cornerRadius(RR.card)
            .overlay(
                RoundedRectangle(cornerRadius: RR.card)
                    .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
            )
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

        viewModel.addComment(to: video.id, text: trimmed)
        newCommentText = ""
    }
}

// MARK: - Comment Bubble

/// A single comment in the thread. Left-aligned card style.
/// Tap to enter inline edit mode — text becomes a TextEditor.
struct CommentBubble: View {
    let comment: IdeaComment
    let isEditing: Bool
    @Binding var editText: String
    let onTap: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RS.xs) {
            // Author + timestamp
            HStack {
                Text(comment.authorName)
                    .font(RF.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.riffitTextPrimary)

                Spacer()

                if isEditing {
                    // Save / Cancel buttons while editing
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
                } else {
                    Text(comment.createdAt.relativeTimestamp)
                        .font(RF.caption)
                        .foregroundStyle(Color.riffitTextTertiary)
                }
            }

            // Inline edit or read-only display
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
