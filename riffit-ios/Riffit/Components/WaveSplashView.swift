import SwiftUI

/// Wave-textured loading screen shown while the app initializes.
/// Multiple overlapping sine waves in teal undulate with parallax motion.
/// A gold shimmer catches each wave crest. The Riffit wordmark and tagline
/// are centered. Fades out when isLoading becomes false.
struct WaveSplashView: View {
    @Binding var isLoading: Bool

    /// Controls the fade-out when loading completes
    @State private var isVisible: Bool = true

    var body: some View {
        ZStack {
            // Deep dark background
            Color(hex: 0x111111)
                .ignoresSafeArea()

            // Animated wave layers
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                Canvas { context, size in
                    drawWaves(context: context, size: size, time: time)
                }
                .ignoresSafeArea()
            }

            // Wordmark + tagline centered
            VStack(spacing: RS.sm) {
                Text("Riffit")
                    .font(.custom("Lora-Bold", size: 32))
                    .foregroundStyle(Color.riffitPrimary)

                Text("scroll, riff, post")
                    .font(.custom("Lora-Italic", size: 13))
                    .foregroundStyle(Color.riffitTeal400)
                    .kerning(1.0)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .onChange(of: isLoading) { _, newValue in
            if !newValue {
                withAnimation(.easeInOut(duration: 0.4)) {
                    isVisible = false
                }
            }
        }
        .allowsHitTesting(isLoading)
    }

    // MARK: - Wave Drawing

    /// Draws 4 layered sine waves from dark to light teal, with a gold shimmer on crests.
    private func drawWaves(context: GraphicsContext, size: CGSize, time: Double) {
        let waveConfigs: [(color: Color, opacity: Double, amplitude: CGFloat, frequency: CGFloat, speed: Double, yOffset: CGFloat)] = [
            // Deepest wave — teal 900, slow, large amplitude, sits lowest
            (Color.riffitTeal900, 0.7,  40, 1.2, 0.3,  size.height * 0.55),
            // Mid-dark wave — teal 600
            (Color.riffitTeal600, 0.5,  30, 1.5, 0.5,  size.height * 0.60),
            // Mid-light wave — teal 400
            (Color.riffitTeal400, 0.35, 22, 1.8, 0.7,  size.height * 0.65),
            // Lightest wave — teal 400, fastest, smallest
            (Color.riffitTeal400, 0.2,  15, 2.2, 1.0,  size.height * 0.70),
        ]

        for config in waveConfigs {
            let phase = time * config.speed
            let path = wavePath(
                width: size.width,
                height: size.height,
                amplitude: config.amplitude,
                frequency: config.frequency,
                phase: phase,
                yOffset: config.yOffset
            )

            // Fill the wave body
            context.fill(path, with: .color(config.color.opacity(config.opacity)))

            // Gold shimmer along the wave crest
            let shimmerPath = waveStrokePath(
                width: size.width,
                amplitude: config.amplitude,
                frequency: config.frequency,
                phase: phase,
                yOffset: config.yOffset
            )
            context.stroke(
                shimmerPath,
                with: .color(Color.riffitPrimary.opacity(0.08)),
                lineWidth: 1.5
            )
        }
    }

    /// Creates a filled wave shape: sine curve on top, bottom of screen below.
    private func wavePath(
        width: CGFloat,
        height: CGFloat,
        amplitude: CGFloat,
        frequency: CGFloat,
        phase: Double,
        yOffset: CGFloat
    ) -> Path {
        var path = Path()
        let step: CGFloat = 2

        path.move(to: CGPoint(x: 0, y: height))

        // Start at the left edge, at the wave height
        let startY = yOffset + amplitude * sin(CGFloat(phase) * .pi * 2)
        path.addLine(to: CGPoint(x: 0, y: startY))

        // Draw the sine curve across the width
        var x: CGFloat = step
        while x <= width {
            let normalizedX = x / width
            let y = yOffset + amplitude * sin((normalizedX * frequency + CGFloat(phase)) * .pi * 2)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        // Close at bottom-right and bottom-left
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()

        return path
    }

    /// Creates just the top stroke of the wave (for the gold shimmer effect).
    private func waveStrokePath(
        width: CGFloat,
        amplitude: CGFloat,
        frequency: CGFloat,
        phase: Double,
        yOffset: CGFloat
    ) -> Path {
        var path = Path()
        let step: CGFloat = 2

        let startY = yOffset + amplitude * sin(CGFloat(phase) * .pi * 2)
        path.move(to: CGPoint(x: 0, y: startY))

        var x: CGFloat = step
        while x <= width {
            let normalizedX = x / width
            let y = yOffset + amplitude * sin((normalizedX * frequency + CGFloat(phase)) * .pi * 2)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        return path
    }
}
