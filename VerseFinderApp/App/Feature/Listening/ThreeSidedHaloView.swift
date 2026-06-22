import SwiftUI

public struct ThreeSidedHaloView: View {
    public var cornerRadius: CGFloat
    public var haloColor: Color

    // Tunables (thicker, premium)
    private let haloWidth: CGFloat = 16
    private let haloBlur: CGFloat = 30
    private let haloOpacity: Double = 0.48

    public init(cornerRadius: CGFloat, haloColor: Color = .accentColor) {
        self.cornerRadius = cornerRadius
        self.haloColor = haloColor
    }

    public var body: some View {
        ZStack(alignment: .center) {
            // Left band
            Rectangle()
                .fill(haloColor.opacity(haloOpacity))
                .frame(width: haloWidth)
                .frame(maxHeight: .infinity, alignment: .leading)
                .blur(radius: haloBlur)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .alignmentGuide(.leading) { d in d[.leading] }

            // Right band
            Rectangle()
                .fill(haloColor.opacity(haloOpacity))
                .frame(width: haloWidth)
                .frame(maxHeight: .infinity, alignment: .trailing)
                .blur(radius: haloBlur)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .alignmentGuide(.trailing) { d in d[.trailing] }

            // Bottom band
            Rectangle()
                .fill(haloColor.opacity(haloOpacity))
                .frame(height: haloWidth)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .blur(radius: haloBlur)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .alignmentGuide(.bottom) { d in d[.bottom] }
        }
        // Clip once to the keyboard rounded shape
        .mask(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        // Fade out the top 10-20% to avoid any blur spill at the top edge
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.12),
                    .init(color: .white, location: 0.22),
                    .init(color: .white, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ThreeSidedHaloView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(Color(UIColor.secondarySystemBackground))
            ThreeSidedHaloView(cornerRadius: 18, haloColor: .blue)
        }
        .frame(width: 360, height: 300)
        .padding()
    }
}
