import SwiftUI
import WebKit

/// Detail view shown when tapping an InspirationCard.
/// Displays the video in an embedded webview, alignment score/verdict,
/// full transcript, and deconstruction data when available.
struct InspirationDetailView: View {
    let video: InspirationVideo

    @State private var showFullTranscript: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .lg) {
                // Embedded video webview
                videoPlayer

                // Alignment section
                if video.status == .analyzed {
                    alignmentSection
                }

                // Transcript section
                if let transcript = video.transcript, !transcript.isEmpty {
                    transcriptSection(transcript)
                }

                // User note
                if let note = video.userNote, !note.isEmpty {
                    noteSection(note)
                }

                // Status indicator for non-analyzed videos
                if video.status == .pending || video.status == .analyzing {
                    statusSection
                }
            }
            .padding(.md)
        }
        .background(Color.riffitBackground)
        .navigationTitle(video.platform.displayLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Video Player

    private var videoPlayer: some View {
        VideoWebView(url: video.url)
            .frame(height: 280)
            .cornerRadius(.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: .cardRadius)
                    .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
            )
    }

    // MARK: - Alignment Section

    private var alignmentSection: some View {
        VStack(alignment: .leading, spacing: .smPlus) {
            Text("Alignment")
                .riffitLabel()
                .foregroundStyle(Color.riffitTextTertiary)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: .sm) {
                    if let verdict = video.alignmentVerdict {
                        AlignmentBadge(verdict: verdict)
                    }

                    if let reasoning = video.alignmentReasoning {
                        Text(reasoning)
                            .riffitBody()
                            .foregroundStyle(Color.riffitTextSecondary)
                    }
                }

                Spacer()

                if let score = video.alignmentScore {
                    VStack(spacing: 2) {
                        Text("\(score)")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(Color.riffitPrimary)

                        Text("/ 100")
                            .riffitCaption()
                            .foregroundStyle(Color.riffitTextTertiary)
                    }
                }
            }
            .riffitCard()
        }
    }

    // MARK: - Transcript Section

    private func transcriptSection(_ transcript: String) -> some View {
        VStack(alignment: .leading, spacing: .smPlus) {
            Text("Transcript")
                .riffitLabel()
                .foregroundStyle(Color.riffitTextTertiary)

            VStack(alignment: .leading, spacing: .sm) {
                Text(transcript)
                    .riffitBody()
                    .foregroundStyle(Color.riffitTextSecondary)
                    .lineLimit(showFullTranscript ? nil : 6)

                if transcript.count > 200 {
                    Button(showFullTranscript ? "Show less" : "Show full transcript") {
                        withAnimation {
                            showFullTranscript.toggle()
                        }
                    }
                    .riffitCaption()
                    .foregroundStyle(Color.riffitTeal400)
                }
            }
            .riffitCard()
        }
    }

    // MARK: - Note Section

    private func noteSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: .smPlus) {
            Text("Your Note")
                .riffitLabel()
                .foregroundStyle(Color.riffitTextTertiary)

            Text(note)
                .riffitBody()
                .foregroundStyle(Color.riffitTextSecondary)
                .riffitCard()
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack(spacing: .smPlus) {
            if video.status == .analyzing {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.riffitPrimary)
            } else {
                Image(systemName: "clock")
                    .foregroundStyle(Color.riffitTextTertiary)
            }

            Text(video.status == .analyzing ? "Analysis in progress..." : "Waiting to analyze")
                .riffitBody()
                .foregroundStyle(Color.riffitTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .riffitCard()
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
