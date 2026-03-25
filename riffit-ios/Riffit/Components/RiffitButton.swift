import SwiftUI

/// Reusable button component with four variants: primary, secondary, ghost, and danger.
/// Primary buttons use the sunset gold fill with dark text.
/// All buttons are 50pt tall, full-width preferred, 10pt corner radius.
struct RiffitButton: View {
    let title: String
    let variant: Variant
    let action: () -> Void

    enum Variant {
        case primary
        case secondary
        case ghost
        case ghostGold
        case danger
    }

    var body: some View {
        if variant == .ghostGold {
            Button(action: action) {
                Text(title)
                    .font(RF.button)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(RiffitGhostGoldButtonStyle())
        } else {
            Button(action: action) {
                Text(title)
                    .font(RF.button)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(foregroundColor)
                    .background(backgroundColor)
                    .cornerRadius(RR.button)
                    .overlay(borderOverlay)
            }
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return Color.riffitOnPrimary
        case .secondary:
            return Color.riffitPrimary
        case .ghost, .ghostGold:
            return Color.riffitTeal600
        case .danger:
            return Color.riffitDanger
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            return Color.riffitPrimary
        case .secondary:
            return Color.riffitElevated
        case .ghost, .ghostGold:
            return Color.riffitTealTint
        case .danger:
            return Color.riffitDangerTint
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch variant {
        case .secondary:
            RoundedRectangle(cornerRadius: RR.button)
                .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
        default:
            EmptyView()
        }
    }
}

// MARK: - Ghost Gold Button Style

/// Dark-mode empty state CTA style.
/// Default: #111111 fill, gold text, gold 1pt border.
/// Pressed: gold fill, #111111 text, no border.
/// Animates fill + text color with .easeInOut 0.15s.
struct RiffitGhostGoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        configuration.label
            .foregroundStyle(isPressed ? Color(hex: 0x111111) : Color.riffitPrimary)
            .background(
                RoundedRectangle(cornerRadius: RR.button)
                    .fill(isPressed ? Color.riffitPrimary : Color(hex: 0x111111))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RR.button)
                    .stroke(isPressed ? Color.clear : Color.riffitPrimary, lineWidth: 1)
            )
            .cornerRadius(RR.button)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
    }
}
