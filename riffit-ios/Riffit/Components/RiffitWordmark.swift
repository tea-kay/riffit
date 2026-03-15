import SwiftUI
import UIKit

/// A bubbly, multi-stroke wordmark rendered using NSAttributedString.
/// SwiftUI Text doesn't support stroke/outline effects, so we use
/// UIViewRepresentable to wrap a custom UIView that draws 6 layers
/// of text back-to-front to create the outlined "Riffit" logotype.
struct RiffitWordmark: UIViewRepresentable {
    var fontSize: CGFloat = 56

    func makeUIView(context: Context) -> RiffitWordmarkUIView {
        let view = RiffitWordmarkUIView()
        view.fontSize = fontSize
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }

    func updateUIView(_ uiView: RiffitWordmarkUIView, context: Context) {
        uiView.fontSize = fontSize
        uiView.setNeedsDisplay()
        uiView.invalidateIntrinsicContentSize()
    }
}

// MARK: - Custom UIView

/// Draws the "Riffit" wordmark with multi-stroke outlines and shadows.
/// Layers (back to front):
/// 1. Deep shadow — dark teal, offset down-right
/// 2. Coral shadow — coral burn, offset down-right
/// 3. Thick dark teal outline (stroke only)
/// 4. Medium teal outline (stroke only)
/// 5. Thin amber outline (stroke only)
/// 6. Gold fill (no stroke)
class RiffitWordmarkUIView: UIView {
    var fontSize: CGFloat = 56

    private var wordmarkFont: UIFont {
        UIFont(name: "Georgia-BoldItalic", size: fontSize)
            ?? UIFont.boldSystemFont(ofSize: fontSize)
    }

    override var intrinsicContentSize: CGSize {
        let attrs: [NSAttributedString.Key: Any] = [.font: wordmarkFont]
        let textSize = ("Riffit" as NSString).size(withAttributes: attrs)
        // Extra space for shadows (+4,+4) and thick stroke (8pt each side)
        return CGSize(width: textSize.width + 20, height: textSize.height + 16)
    }

    override func draw(_ rect: CGRect) {
        let font = wordmarkFont
        let text = "Riffit"

        // Calculate text size and center it in the view
        let baseAttrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: baseAttrs)
        let x = (rect.width - textSize.width) / 2
        let y = (rect.height - textSize.height) / 2
        let origin = CGPoint(x: x, y: y)

        // Layer 1: Deep shadow — dark teal at 40% opacity, offset +4/+4
        drawLayer(text, at: CGPoint(x: origin.x + 4, y: origin.y + 4),
                  font: font,
                  fill: UIColor(red: 10/255.0, green: 74/255.0, blue: 82/255.0, alpha: 0.4))

        // Layer 2: Coral shadow — coral burn at 35% opacity, offset +2/+2
        drawLayer(text, at: CGPoint(x: origin.x + 2, y: origin.y + 2),
                  font: font,
                  fill: UIColor(red: 217/255.0, green: 78/255.0, blue: 42/255.0, alpha: 0.35))

        // Layer 3: Thick dark teal outline — #0A4A52, strokeWidth 16
        drawLayer(text, at: origin, font: font,
                  stroke: UIColor(red: 10/255.0, green: 74/255.0, blue: 82/255.0, alpha: 1),
                  strokeWidth: 16)

        // Layer 4: Medium teal outline — #0F6B75, strokeWidth 10
        drawLayer(text, at: origin, font: font,
                  stroke: UIColor(red: 15/255.0, green: 107/255.0, blue: 117/255.0, alpha: 1),
                  strokeWidth: 10)

        // Layer 5: Thin amber outline — #E87820, strokeWidth 4
        drawLayer(text, at: origin, font: font,
                  stroke: UIColor(red: 232/255.0, green: 120/255.0, blue: 32/255.0, alpha: 1),
                  strokeWidth: 4)

        // Layer 6: Gold fill — #F0AA20, no stroke
        drawLayer(text, at: origin, font: font,
                  fill: UIColor(red: 240/255.0, green: 170/255.0, blue: 32/255.0, alpha: 1))
    }

    /// Draws a single text layer with either a fill color, stroke, or both.
    /// - Parameters:
    ///   - fill: The foreground fill color (nil for stroke-only layers)
    ///   - stroke: The stroke outline color (nil for fill-only layers)
    ///   - strokeWidth: Positive = stroke only, negative = stroke + fill
    private func drawLayer(_ text: String, at point: CGPoint, font: UIFont,
                           fill: UIColor? = nil, stroke: UIColor? = nil,
                           strokeWidth: CGFloat = 0) {
        var attrs: [NSAttributedString.Key: Any] = [.font: font]

        if let stroke {
            attrs[.strokeColor] = stroke
            // Positive strokeWidth → stroke only (no fill inside)
            attrs[.strokeWidth] = strokeWidth
        }

        if let fill {
            attrs[.foregroundColor] = fill
        }

        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}
