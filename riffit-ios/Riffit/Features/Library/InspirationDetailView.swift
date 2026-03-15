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
    @FocusState private var isCommentFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: RS.lg) {
                        // Embedded video webview
                        videoPlayer

                        // Tags row
                        let tags = viewModel.tags(for: video.id)
                        if !tags.isEmpty {
                            tagsRow(tags)
                        }

                        // Alignment section
                        if video.status == .analyzed {
                            alignmentSection
                        }

                        // Transcript section
                        if let transcript = video.transcript, !transcript.isEmpty {
                            transcriptSection(transcript)
                        }

                        // Status indicator for non-analyzed videos
                        if video.status == .pending || video.status == .analyzing {
                            statusSection
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

    // MARK: - Tags Row

    private func tagsRow(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(RF.tag)
                        .foregroundStyle(Color.riffitPrimary)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(Color.riffitPrimaryTint)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Alignment Section

    private var alignmentSection: some View {
        VStack(alignment: .leading, spacing: RS.smPlus) {
            Text("Alignment")
                .font(RF.label)
                .textCase(.uppercase)
                .tracking(0.08 * 13)
                .foregroundStyle(Color.riffitTextTertiary)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: RS.sm) {
                    if let verdict = video.alignmentVerdict {
                        AlignmentBadge(verdict: verdict)
                    }

                    if let reasoning = video.alignmentReasoning {
                        Text(reasoning)
                            .font(RF.bodyMd)
                            .foregroundStyle(Color.riffitTextSecondary)
                    }
                }

                Spacer()

                if let score = video.alignmentScore {
                    VStack(spacing: 2) {
                        Text("\(score)")
                            .font(RF.display(36))
                            .foregroundStyle(Color.riffitPrimary)

                        Text("/ 100")
                            .font(RF.caption)
                            .foregroundStyle(Color.riffitTextTertiary)
                    }
                }
            }
            .riffitCard()
        }
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

    // MARK: - Status Section

    private var statusSection: some View {
        HStack(spacing: RS.smPlus) {
            if video.status == .analyzing {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.riffitPrimary)
            } else {
                Image(systemName: "clock")
                    .foregroundStyle(Color.riffitTextTertiary)
            }

            Text(video.status == .analyzing ? "Analysis in progress..." : "Waiting to analyze")
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .riffitCard()
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
                    CommentBubble(comment: comment)
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

/// A single comment in the thread. Left-aligned card style (not a DM bubble).
struct CommentBubble: View {
    let comment: IdeaComment

    var body: some View {
        VStack(alignment: .leading, spacing: RS.xs) {
            // Author + timestamp
            HStack {
                Text(comment.authorName)
                    .font(RF.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.riffitTextPrimary)

                Spacer()

                Text(comment.createdAt.relativeTimestamp)
                    .font(RF.caption)
                    .foregroundStyle(Color.riffitTextTertiary)
            }

            // Comment text
            Text(comment.text)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextSecondary)
        }
        .padding(RS.smPlus)
        .background(Color.riffitSurface)
        .cornerRadius(RR.input)
        .overlay(
            RoundedRectangle(cornerRadius: RR.input)
                .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
        )
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
