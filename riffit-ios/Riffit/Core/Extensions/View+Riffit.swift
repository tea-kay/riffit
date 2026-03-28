import SwiftUI

/// Common SwiftUI view modifiers used throughout the Riffit app.
extension View {
    /// Applies the standard Riffit card style: surface background,
    /// 20pt corner radius, and subtle border.
    func riffitCard() -> some View {
        self
            .padding(RS.md)
            .background(Color.riffitSurface)
            .cornerRadius(RR.card)
            .overlay(
                RoundedRectangle(cornerRadius: RR.card)
                    .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
            )
    }

    /// Applies the standard Riffit row style: surface background,
    /// 14pt corner radius.
    func riffitRow() -> some View {
        self
            .padding(RS.md)
            .background(Color.riffitSurface)
            .cornerRadius(RR.input)
    }

    /// Presents content as a centered modal dialog with dimmed backdrop.
    /// Animates in with scale + opacity. Tap outside to dismiss.
    func riffitModal<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.overlay {
            ZStack {
                if isPresented.wrappedValue {
                    // Dimmed backdrop — tap to dismiss
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                isPresented.wrappedValue = false
                            }
                        }

                    // Centered card
                    content()
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isPresented.wrappedValue)
        }
    }
}

// MARK: - Riffit Input Modal

/// Centered modal dialog with title, text field, Cancel + action button.
/// Used for "New Story", "New Folder", "Rename Folder", etc.
struct RiffitInputModal: View {
    let title: String
    let placeholder: String
    let actionLabel: String
    @Binding var text: String
    let onCancel: () -> Void
    let onAction: (String) -> Void

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: RS.lg) {
            Text(title)
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)

            TextField(placeholder, text: $text)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextPrimary)
                .padding(RS.smPlus)
                .background(Color.riffitBackground)
                .cornerRadius(RR.input)
                .overlay(
                    RoundedRectangle(cornerRadius: RR.input)
                        .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                )

            // Buttons
            HStack(spacing: RS.smPlus) {
                // Cancel
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(RF.button)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(Color.riffitTextSecondary)
                        .background(Color.riffitBackground)
                        .cornerRadius(RR.button)
                        .overlay(
                            RoundedRectangle(cornerRadius: RR.button)
                                .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                        )
                }

                // Action (Create / Save)
                Button {
                    if !trimmedText.isEmpty {
                        onAction(trimmedText)
                    }
                } label: {
                    Text(actionLabel)
                        .font(RF.button)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(Color.riffitOnPrimary)
                        .background(trimmedText.isEmpty ? Color.riffitPrimary.opacity(0.4) : Color.riffitPrimary)
                        .cornerRadius(RR.button)
                }
                .disabled(trimmedText.isEmpty)
            }
        }
        .padding(RS.lg)
        .background(Color.riffitSurface)
        .cornerRadius(RR.card)
        .padding(.horizontal, 32)
    }
}

// MARK: - Riffit Action Modal

/// Centered modal for action menus — replaces system Menu/ActionSheet
/// so all text uses Riffit fonts. Each action is a full-width row.
struct RiffitActionModal: View {
    let actions: [ActionItem]
    let onDismiss: () -> Void

    struct ActionItem {
        let label: String
        let icon: String
        let action: () -> Void
    }

    var body: some View {
        VStack(spacing: RS.smPlus) {
            ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
                Button {
                    onDismiss()
                    item.action()
                } label: {
                    HStack(spacing: RS.smPlus) {
                        Image(systemName: item.icon)
                            .font(.body)
                            .foregroundStyle(Color.riffitPrimary)
                            .frame(width: 28, height: 28)

                        Text(item.label)
                            .font(RF.button)
                            .foregroundStyle(Color.riffitTextPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.riffitTextTertiary)
                    }
                    .padding(RS.md)
                    .background(Color.riffitBackground)
                    .cornerRadius(RR.input)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(RS.lg)
        .background(Color.riffitSurface)
        .cornerRadius(RR.card)
        .padding(.horizontal, 32)
    }
}
