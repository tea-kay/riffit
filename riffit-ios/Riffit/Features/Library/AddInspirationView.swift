import SwiftUI

/// Sheet for submitting an Instagram link with a note about
/// what caught your eye. IG-only for now — other platforms later.
struct AddInspirationView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var urlText: String = ""
    @State private var userNote: String = ""
    @State private var showError: Bool = false

    enum Field {
        case url
        case note
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: .lg) {
                // URL input
                VStack(alignment: .leading, spacing: .sm) {
                    Text("Instagram Link")
                        .riffitLabel()
                        .foregroundStyle(Color.riffitTextTertiary)

                    TextField("Paste an Instagram reel or post URL...", text: $urlText)
                        .riffitBody()
                        .foregroundStyle(Color.riffitTextPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .focused($focusedField, equals: .url)
                        .padding(.smPlus)
                        .background(Color.riffitSurface)
                        .cornerRadius(.inputRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: .inputRadius)
                                .stroke(showError ? Color.riffitDanger : Color.riffitBorderDefault, lineWidth: 0.5)
                        )
                        .onChange(of: urlText) { showError = false }

                    if showError {
                        Text("Paste a valid Instagram link (instagram.com or instagr.am).")
                            .riffitCaption()
                            .foregroundStyle(Color.riffitDanger)
                    }
                }

                // Note input
                VStack(alignment: .leading, spacing: .sm) {
                    Text("What's the idea?")
                        .riffitLabel()
                        .foregroundStyle(Color.riffitTextTertiary)

                    TextField("What caught your eye? What would you riff on?", text: $userNote, axis: .vertical)
                        .lineLimit(3...6)
                        .riffitBody()
                        .foregroundStyle(Color.riffitTextPrimary)
                        .focused($focusedField, equals: .note)
                        .padding(.smPlus)
                        .background(Color.riffitSurface)
                        .cornerRadius(.inputRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: .inputRadius)
                                .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                        )
                }

                Spacer()

                // Submit button
                RiffitButton(title: "Save Idea", variant: .primary) {
                    submit()
                }
            }
            .padding(.md)
            .background(Color.riffitBackground)
            .navigationTitle("New Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.riffitTextSecondary)
                }
            }
            .onAppear {
                focusedField = .url
            }
        }
    }

    // MARK: - Submit

    private func submit() {
        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isInstagramURL(trimmedURL) else {
            showError = true
            return
        }

        let trimmedNote = userNote.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            await viewModel.addVideo(
                url: trimmedURL,
                platform: .instagram,
                userNote: trimmedNote.isEmpty ? nil : trimmedNote
            )
        }

        dismiss()
    }

    private func isInstagramURL(_ urlString: String) -> Bool {
        let lowered = urlString.lowercased()
        return lowered.contains("instagram.com") || lowered.contains("instagr.am")
    }
}
