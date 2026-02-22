import SwiftUI

/// A SwiftUI preview helper for generating the app icon.
/// Run this preview in Xcode Canvas, then screenshot at 1024x1024 for the asset catalog.
struct AppIconPreview: View {
    private let accentBlue = Color(red: 0.271, green: 0.435, blue: 0.867)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [accentBlue, accentBlue.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: -8) {
                ZStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 280, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                        .offset(y: 40)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 380, weight: .thin))
                        .foregroundStyle(.white)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 100, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .offset(x: 80, y: -60)
                }
            }
        }
        .frame(width: 1024, height: 1024)
        .clipShape(RoundedRectangle(cornerRadius: 224, style: .continuous))
    }
}

#Preview("App Icon 1024x1024", traits: .fixedLayout(width: 1024, height: 1024)) {
    AppIconPreview()
}
