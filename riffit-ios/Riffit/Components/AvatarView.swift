import SwiftUI

/// Reusable avatar circle for the current user.
/// Renders a locally cached UIImage when available, falling back to an
/// initials circle. Because the image is already in memory (set by AppState
/// during auth), this renders instantly with no network request.
///
/// For OTHER users' avatars, keep using AsyncImage — this component is
/// only for the current user's avatar where we own the image lifecycle.
struct AvatarView: View {
    let image: UIImage?
    let fallbackInitial: String
    let size: CGFloat

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Text(fallbackInitial)
                .font(size <= 32 ? RF.caption : RF.heading)
                .foregroundStyle(Color.riffitTextPrimary)
                .frame(width: size, height: size)
                .background(Color.riffitTeal600)
                .clipShape(Circle())
        }
    }
}
