import SwiftUI

/// Full-screen viewer for an image asset.
/// Shows the image with an editable title. Tapping Done saves title changes.
struct ImageViewerView: View {
    let asset: StoryAsset
    @ObservedObject var viewModel: StorybankViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var titleText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: RS.lg) {
                // Editable title
                TextField("Image", text: $titleText)
                    .font(RF.heading)
                    .foregroundStyle(Color.riffitTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, RS.lg)
                    .padding(.top, RS.lg)

                // Image display
                if let path = asset.fileUrl,
                   let uiImage = ImageStorageService.load(from: path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(RR.card)
                        .padding(.horizontal, RS.md)
                } else {
                    // Fallback if image can't be loaded
                    VStack(spacing: RS.sm) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.riffitTextTertiary)

                        Text("Image not found")
                            .font(RF.caption)
                            .foregroundStyle(Color.riffitTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RS.xl3)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.riffitBackground)
            .navigationTitle("Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                        viewModel.updateAsset(
                            asset,
                            name: trimmed.isEmpty ? nil : trimmed,
                            text: asset.contentText ?? ""
                        )
                        dismiss()
                    }
                    .font(RF.button)
                    .foregroundStyle(Color.riffitPrimary)
                }
            }
        }
        .onAppear {
            titleText = asset.name ?? "Image"
        }
    }
}
