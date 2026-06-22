//
//  FuturisticLoadingView.swift
//  VerseFinderApp
//
//  Created by Assistant on 2026/03/07.
//

import SwiftUI

public struct FuturisticLoadingView: View {
    @State private var beamOffset: CGFloat = -240
    @State private var pulse: Bool = false
    @State private var haloPulse: Bool = false
    @State private var particles: [CGPoint] = (0..<24).map { _ in CGPoint(x: .random(in: -140...140), y: .random(in: -60...60)) }

    public init() {}

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
                        .blur(radius: 1)
                        .opacity(0.8)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.0),
                            Color.accentColor.opacity(0.55),
                            Color.blue.opacity(0.35),
                            Color.purple.opacity(0.35),
                            Color.accentColor.opacity(0.0)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: haloPulse ? 8 : 5
                )
                .blur(radius: haloPulse ? 14 : 8)
                .scaleEffect(haloPulse ? 1.02 : 0.99)
                .opacity(0.9)

            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(0.05),
                    Color.accentColor.opacity(0.35),
                    Color.accentColor.opacity(0.05)
                ]),
                startPoint: .leading, endPoint: .trailing
            )
            .mask(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .opacity(0.9)
                    .offset(x: beamOffset)
            )
            .blur(radius: 18)

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.28))
                    .frame(width: pulse ? 240 : 190, height: pulse ? 240 : 190)
                    .blur(radius: 36)
                    .offset(x: -90, y: -30)
                Circle()
                    .fill(Color.blue.opacity(0.24))
                    .frame(width: pulse ? 200 : 160, height: pulse ? 200 : 160)
                    .blur(radius: 32)
                    .offset(x: 100, y: 50)
            }

            GeometryReader { geo in
                ForEach(particles.indices, id: \.self) { idx in
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 3, height: 3)
                        .position(x: geo.size.width / 2 + particles[idx].x, y: geo.size.height / 2 + particles[idx].y)
                        .blur(radius: 0.5)
                        .onAppear {
                            withAnimation(.linear(duration: Double.random(in: 2.5...4.5)).repeatForever(autoreverses: true)) {
                                particles[idx].x += CGFloat.random(in: -20...20)
                                particles[idx].y += CGFloat.random(in: -10...10)
                            }
                        }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.25)).frame(width: 140, height: 16)
                    Spacer()
                    Image(systemName: "sparkles")
                        .foregroundColor(.accentColor.opacity(0.7))
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.accentColor.opacity(0.12))
                        )
                }
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.22)).frame(height: 14)
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.22)).frame(height: 14)
                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.22)).frame(height: 14)
            }
            .padding(20)
        }
        .frame(height: 240)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                beamOffset = 240
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                haloPulse = true
            }
        }
    }
}
