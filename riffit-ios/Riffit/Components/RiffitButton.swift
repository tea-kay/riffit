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
        case danger
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .modifier(ButtonFontModifier(variant: variant))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(foregroundColor)
                .background(backgroundColor)
                .cornerRadius(.buttonRadius)
                .overlay(borderOverlay)
        }
    }

    /// All button variants use Lora Medium 16pt.
    private struct ButtonFontModifier: ViewModifier {
        let variant: Variant
        func body(content: Content) -> some View {
            content.font(.riffitButton)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return Color.riffitOnPrimary
        case .secondary:
            return Color.riffitPrimary
        case .ghost:
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
        case .ghost:
            return Color.riffitTealTint
        case .danger:
            return Color.riffitDangerTint
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch variant {
        case .secondary:
            RoundedRectangle(cornerRadius: .buttonRadius)
                .stroke(Color.riffitBorderDefault, lineWidth: 0.5)
        default:
            EmptyView()
        }
    }
}
