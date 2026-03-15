import SwiftUI

/// Full-screen translucent overlay with a progress indicator.
/// Used when waiting for edge function responses (analysis, brief generation, etc.)
struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: .md) {
                ProgressView()
                    .tint(Color.riffitPrimary)

                Text(message)
                    .font(.riffitBody)
                    .foregroundStyle(Color.riffitTextPrimary)
            }
            .padding(.xl)
            .background(Color.riffitElevated)
            .cornerRadius(.cardRadius)
        }
    }
}
