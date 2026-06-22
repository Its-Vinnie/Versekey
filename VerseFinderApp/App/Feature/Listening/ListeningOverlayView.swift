import SwiftUI

public struct ListeningOverlayView: View {
    let transcript: String
    let cornerRadius: CGFloat
    let onCancel: () -> Void
    let onSend: () -> Void

    public init(transcript: String, cornerRadius: CGFloat, onCancel: @escaping () -> Void, onSend: @escaping () -> Void) {
        self.transcript = transcript
        self.cornerRadius = cornerRadius
        self.onCancel = onCancel
        self.onSend = onSend
    }

    public var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { }
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                .shadow(color: Color.accentColor.opacity(0.55), radius: 22, x: 0, y: 0)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 38, x: 0, y: 0)
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                Spacer(minLength: 28)

                Text(transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Listening…" : transcript)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(UIColor.separator).opacity(0.28), lineWidth: 0.75)
                    )
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)

                HStack(spacing: 28) {
                    materialCircleButton(systemName: "xmark", tint: .red, action: onCancel)
                    materialCircleButton(systemName: "paperplane.fill", tint: .accentColor, action: onSend)
                }
                .padding(.bottom, 18)
            }
            .padding(.horizontal, 20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Listening overlay")
    }

    private func materialCircleButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.18), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName == "xmark" ? "Cancel" : "Send")
    }
}

struct ListeningOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(Color(UIColor.secondarySystemBackground))
            ListeningOverlayView(transcript: "Find John three sixteen in NIV", cornerRadius: 18, onCancel: {}, onSend: {})
        }
        .frame(height: 380)
        .padding()
    }
}
