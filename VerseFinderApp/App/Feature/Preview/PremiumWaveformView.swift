import SwiftUI

// Namespaced listening UI components to avoid global redeclaration conflicts
public enum VKListeningUI {

    // MARK: - Ambient Wave + Listening Overlay

    /// Subtle bottom ambient blue halo with slow drift/breathe, designed to sit behind controls.
    public struct BottomAmbientWaveView: View {
        @State private var t: CGFloat = 0
        @State private var breathe: Bool = false

        public var haloColor: Color
        public var coreColor: Color
        public var intensity: CGFloat // 0.0 ... 1.0
        public var amplitude: CGFloat

        public init(haloColor: Color = .accentColor,
                    coreColor: Color = Color(red: 0.04, green: 0.09, blue: 0.19),
                    intensity: CGFloat = 1.0,
                    amplitude: CGFloat = 0.0) {
            self.haloColor = haloColor
            self.coreColor = coreColor
            self.intensity = intensity
            self.amplitude = amplitude
        }

        private var breathOpacity: Double {
            let base = 0.18 + (0.10 * Double(intensity))
            return breathe ? base + 0.08 : base - 0.06
        }

        private var ampMapped: (opacity: Double, yScale: CGFloat, blur: CGFloat) {
            let a = max(0, min(1, amplitude))
            let opacity = 0.18 + Double(a) * 0.22
            let yScale: CGFloat = 1.00 + a * 0.10
            let blur: CGFloat = 40 + a * 18
            return (opacity, yScale, blur)
        }

        public var body: some View {
            GeometryReader { geo in
                let w: CGFloat = geo.size.width
                let h: CGFloat = geo.size.height
                let animT: CGFloat = t
                let amp = ampMapped

                ZStack {
                    haloBands(width: w, height: h, animT: animT)
                        .opacity(amp.opacity)
                        .scaleEffect(x: 1.0, y: amp.yScale, anchor: .bottom)
                }
                .blur(radius: amp.blur)
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                        t = 8 * .pi
                    }
                    withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                        breathe.toggle()
                    }
                }
            }
        }

        private func haloBands(width w: CGFloat, height h: CGFloat, animT: CGFloat) -> some View {
            let baseCore = coreColor.opacity(0.10)
            let shimmer = LinearGradient(colors: [Color.white.opacity(0.10), Color.clear], startPoint: .leading, endPoint: .trailing)
            return ZStack {
                // Depth base: very soft navy to ground the glow
                Ellipse()
                    .fill(baseCore)
                    .frame(width: w * 0.95, height: h * 0.55)
                    .blur(radius: 28)
                    .offset(y: h * 0.18)

                // Overlapping halo bands (fog)
                Group {
                    Capsule()
                        .fill(haloColor.opacity(breathOpacity))
                        .frame(width: w * 0.88, height: h * 0.22)
                        .blur(radius: 26)
                        .offset(x: sin(animT * 0.22) * min(40, w * 0.12), y: h * 0.06 + cos(animT * 0.18) * 10)

                    Capsule()
                        .fill(haloColor.opacity(breathOpacity * 0.85))
                        .frame(width: w * 0.72, height: h * 0.18)
                        .blur(radius: 24)
                        .offset(x: cos(animT * 0.18) * min(34, w * 0.10), y: h * 0.12 + sin(animT * 0.20) * 8)

                    Capsule()
                        .fill(haloColor.opacity(breathOpacity * 0.70))
                        .frame(width: w * 0.60, height: h * 0.16)
                        .blur(radius: 22)
                        .offset(x: -sin(animT * 0.16) * min(28, w * 0.08), y: h * 0.16 + cos(animT * 0.16) * 7)

                    Capsule()
                        .fill(haloColor.opacity(breathOpacity * 0.50))
                        .frame(width: w * 0.50, height: h * 0.14)
                        .blur(radius: 20)
                        .offset(x: cos(animT * 0.14) * min(22, w * 0.06), y: h * 0.20 + sin(animT * 0.14) * 6)
                }

                // Gentle shimmer sweep across the band
                Rectangle()
                    .fill(shimmer)
                    .frame(width: w * 0.35, height: h * 0.5)
                    .blur(radius: 24)
                    .opacity(0.08)
                    .offset(x: (sin(animT * 0.12) * w * 0.35), y: h * 0.08)

                // Subtle sparkles
                sparkles(width: w, height: h, animT: animT)
            }
        }

        private func sparkles(width w: CGFloat, height h: CGFloat, animT: CGFloat) -> some View {
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    let fx: CGFloat = CGFloat(i) / 8.0
                    let phase1: CGFloat = 0.10 + 0.02 * CGFloat(i)
                    let phase2: CGFloat = 0.15 + 0.015 * CGFloat(i)
                    let phase3: CGFloat = 0.20 + 0.03 * CGFloat(i)
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 2.5, height: 2.5)
                        .blur(radius: 0.6)
                        .offset(x: (fx - 0.5) * w * 0.7 + sin(animT * phase1) * 12,
                                y: h * 0.10 + cos(animT * phase2) * 14)
                        .opacity(0.35 + 0.25 * Double(sin(animT * phase3)))
                }
            }
        }
    }

    /// Listening overlay with glass material, minimal label, ambient wave at bottom, and native controls.
    public struct AmbientListeningOverlay: View {
        public var transcript: String
        public var isListening: Bool
        public var onCancel: () -> Void
        public var onToggleMic: () -> Void
        public var onSend: () -> Void

        // Colors (reuse VerseKey palette)
        private let haloBlue: Color = .accentColor
        private let deepNavy = Color(red: 0.04, green: 0.09, blue: 0.19)

        public init(transcript: String,
                    isListening: Bool,
                    onCancel: @escaping () -> Void,
                    onToggleMic: @escaping () -> Void,
                    onSend: @escaping () -> Void) {
            self.transcript = transcript
            self.isListening = isListening
            self.onCancel = onCancel
            self.onToggleMic = onToggleMic
            self.onSend = onSend
        }

        public var body: some View {
            ZStack {
                // Glassy overlay that samples what’s behind (keyboard) to de-emphasize
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(Color.black.opacity(0.04))

                VStack(spacing: 0) {
                    // Top label area
                    VStack(spacing: 6) {
                        Text(transcript.isEmpty ? "Listening…" : "Listening…")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .opacity(0.95)
                        if !transcript.isEmpty {
                            Text(transcript)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .padding(.horizontal, 12)
                        }
                    }
                    .padding(.top, 14)

                    Spacer(minLength: 0)

                    // Ambient wave zone (lower third)
                    BottomAmbientWaveView(haloColor: haloBlue,
                                          coreColor: deepNavy,
                                          intensity: isListening ? 1.0 : 0.6,
                                          amplitude: 0.35)
                        .frame(height: 240)
                        .padding(.horizontal, 16)
                        .offset(y: -60)
                        .zIndex(0)

                    // Controls row
                    HStack(spacing: 28) {
                        controlButton(systemName: "xmark", size: 56, tint: Color.red.opacity(0.9)) {
                            onCancel()
                        }
                        micButton(size: 68) {
                            onToggleMic()
                        }
                        controlButton(systemName: "paperplane.fill", size: 56, tint: haloBlue) {
                            onSend()
                        }
                    }
                    .zIndex(1)
                    .padding(.bottom, 8)
                }
            }
            .opacity(isListening ? 1 : 0)
            .scaleEffect(isListening ? 1.0 : 0.98)
            .animation(.easeOut(duration: 0.22), value: isListening)
        }

        // MARK: - Controls
        private func controlButton(systemName: String, size: CGFloat, tint: Color, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: size, height: size)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }

        private func micButton(size: CGFloat, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .strokeBorder(LinearGradient(colors: [haloBlue.opacity(0.7), haloBlue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                        .blur(radius: 0.2)
                    Image(systemName: "mic.fill")
                        .font(.system(size: size * 0.46, weight: .semibold))
                        .foregroundStyle(haloBlue)
                }
                .frame(width: size, height: size)
                .shadow(color: haloBlue.opacity(0.45), radius: 10, x: 0, y: 0)
                .shadow(color: haloBlue.opacity(0.25), radius: 18, x: 0, y: 0)
            }
            .buttonStyle(.plain)
        }
    }
}

struct PremiumWaveformView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.12))
                .preferredColorScheme(.dark)

            VKListeningUI.AmbientListeningOverlay(
                transcript: "john one verse two",
                isListening: true,
                onCancel: {},
                onToggleMic: {},
                onSend: {}
            )
        }
    }
}
