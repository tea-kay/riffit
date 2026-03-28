import SwiftUI

/// Reusable confirmation modal that replaces native .alert() for confirmation prompts.
/// Presented as a ZStack overlay via .riffitModal(isPresented:).
///
/// - Destructive actions (delete, leave, remove): coral confirm button
/// - Non-destructive actions (sign out, archive): gold confirm button
struct RiffitConfirmationModal: View {
    let title: String
    let message: String
    let confirmLabel: String
    var isDestructive: Bool = true
    let onConfirm: () -> Void
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: RS.lg) {
            // Title — Georgia Bold Italic, 20pt (matches RF.heading = display(20))
            Text(title)
                .font(RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)
                .multilineTextAlignment(.center)

            // Message — SF Pro 15pt (RF.bodyMd)
            Text(message)
                .font(RF.bodyMd)
                .foregroundStyle(Color.riffitTextSecondary)
                .multilineTextAlignment(.center)

            // Button row
            HStack(spacing: RS.smPlus) {
                // Cancel — secondary style
                Button {
                    onCancel?()
                } label: {
                    Text("Cancel")
                        .font(RF.button)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(Color.riffitTextPrimary)
                        .background(Color.riffitElevated)
                        .cornerRadius(RR.button)
                        .overlay(
                            RoundedRectangle(cornerRadius: RR.button)
                                .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
                        )
                }

                // Confirm — danger (coral) or primary (gold)
                Button {
                    onConfirm()
                } label: {
                    Text(confirmLabel)
                        .font(RF.button)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(isDestructive ? .white : Color.riffitOnPrimary)
                        .background(isDestructive ? Color.riffitDanger : Color.riffitPrimary)
                        .cornerRadius(RR.button)
                }
            }
        }
        .padding(RS.lg)
        .background(Color.riffitSurface)
        .cornerRadius(RR.modal)
        .padding(.horizontal, RS.xl)
    }
}
