import SwiftUI

/// Modal for adding a reference from the Library to a Story.
/// Step 1: Pick an inspiration video from a list.
/// Step 2: Pick which tag you're referencing it for.
/// The AI relevance note will be generated asynchronously via an Edge Function.
struct AddReferenceView: View {
    let story: Story
    @ObservedObject var viewModel: StorybankViewModel
    @Environment(\.dismiss) private var dismiss

    /// The videos to pick from. Injected from the Library.
    /// For now we accept an empty list — the real data will come from
    /// a shared LibraryViewModel or Supabase query.
    @State private var selectedVideo: InspirationVideo?
    @State private var selectedTag: String?
    @State private var step: Step = .pickVideo

    enum Step {
        case pickVideo
        case pickTag
    }

    /// The reference tags a creator can pick from.
    private let referenceTags: [String] = [
        "Hook", "Editing", "B-Roll", "Format", "Topic", "Inspiration"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.riffitBackground
                    .ignoresSafeArea()

                switch step {
                case .pickVideo:
                    pickVideoStep
                case .pickTag:
                    pickTagStep
                }
            }
            .navigationTitle(step == .pickVideo ? "Pick a Video" : "What are you referencing?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.riffitTextSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(.sheetRadius)
    }

    // MARK: - Step 1: Pick Video

    private var pickVideoStep: some View {
        VStack(spacing: .md) {
            // Placeholder — in a real implementation, this would query the
            // user's InspirationVideo list from Supabase or a shared view model.
            Text("Your saved ideas will appear here.\nConnect your Library to add references.")
                .riffitBody()
                .foregroundStyle(Color.riffitTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .xl)
                .padding(.top, .xl2)

            Spacer()
        }
    }

    // MARK: - Step 2: Pick Tag

    private var pickTagStep: some View {
        VStack(spacing: .lg) {
            Text("What aspect of this video are you referencing?")
                .riffitBody()
                .foregroundStyle(Color.riffitTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .lg)
                .padding(.top, .lg)

            // Tag grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: .smPlus) {
                ForEach(referenceTags, id: \.self) { tag in
                    Button {
                        selectedTag = tag
                    } label: {
                        Text(tag)
                            .riffitCallout()
                            .fontWeight(.medium)
                            .foregroundStyle(
                                selectedTag == tag
                                    ? Color(hex: 0x111111)
                                    : Color.riffitTextPrimary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, .smPlus)
                            .background(
                                selectedTag == tag
                                    ? Color.riffitPrimary
                                    : Color.riffitSurface
                            )
                            .cornerRadius(.buttonRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: .buttonRadius)
                                    .stroke(
                                        selectedTag == tag
                                            ? Color.clear
                                            : Color.riffitBorderDefault,
                                        lineWidth: 0.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, .md)

            Spacer()

            // Add reference button
            RiffitButton(title: "Add Reference", variant: .primary) {
                if let video = selectedVideo, let tag = selectedTag {
                    viewModel.addReference(to: story.id, videoId: video.id, tag: tag)
                    dismiss()
                }
            }
            .padding(.horizontal, .md)
            .padding(.bottom, .lg)
            .opacity(selectedTag != nil ? 1.0 : 0.4)
            .disabled(selectedTag == nil)
        }
    }
}
