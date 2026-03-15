import SwiftUI

/// Full-screen translucent overlay with a progress indicator.
/// Used when waiting for edge function responses (analysis, brief generation, etc.)
struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: RS.md) {
                ProgressView()
                    .tint(Color.riffitPrimary)

                Text(message)
                    .font(RF.bodyMd)
                    .foregroundStyle(Color.riffitTextPrimary)
            }
            .padding(RS.xl)
            .background(Color.riffitElevated)
            .cornerRadius(RR.card)
        }
    }
}
