import SwiftUI

/// Common SwiftUI view modifiers used throughout the Riffit app.
extension View {
    /// Applies the standard Riffit card style: surface background,
    /// 20pt corner radius, and subtle border.
    func riffitCard() -> some View {
        self
            .padding(.md)
            .background(Color.riffitSurface)
            .cornerRadius(.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: .cardRadius)
                    .stroke(Color.riffitBorderSubtle, lineWidth: 0.5)
            )
    }

    /// Applies the standard Riffit row style: surface background,
    /// 14pt corner radius.
    func riffitRow() -> some View {
        self
            .padding(.md)
            .background(Color.riffitSurface)
            .cornerRadius(.inputRadius)
    }
}
