import SwiftUI

extension Color {
    static let sOrange    = Color(red: 1.00, green: 0.40, blue: 0.00)
    static let sOrangeEnd = Color(red: 1.00, green: 0.24, blue: 0.498)
    static let sS1        = Color(white: 0.067)
    static let sS2        = Color(white: 0.102)
    static let sS3        = Color(white: 0.142)
    static let sDim       = Color(white: 0.533)
    static let sMuted     = Color(white: 0.267)
}

extension LinearGradient {
    static let sGradient = LinearGradient(
        colors: [.sOrange, .sOrangeEnd],
        startPoint: .leading, endPoint: .trailing
    )
}

extension View {
    func gradientForeground() -> some View {
        self.overlay(LinearGradient.sGradient).mask(self)
    }

    func glassSurface(cornerRadius: CGFloat = 18, tintOpacity: CGFloat = 0.58) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.sS1.opacity(tintOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.22),
                                    .white.opacity(0.05),
                                    .sOrange.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
        )
    }
}
