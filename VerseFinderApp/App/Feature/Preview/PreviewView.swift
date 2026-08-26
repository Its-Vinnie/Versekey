import Combine
import SwiftUI

struct PreviewView: View {
    @State private var clipboardText: String = UIPasteboard.general.string ?? ""
    @State private var showCursor: Bool = true
    @State private var hostInputFocusRevision: Int = 0
    private let hostTextHeight: CGFloat = 250

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hostArea
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                let keyboardHeight: CGFloat = 266
                AppKeyboardPreviewView(
                    showHostArea: false,
                    hostInputFocusRevision: $hostInputFocusRevision
                ) { text in
                    clipboardText = text
                }
                    .frame(maxWidth: .infinity)
                    .frame(height: keyboardHeight)
                    .padding(.bottom, 4)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(.systemBackground),
                                Color(.systemBackground).opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.06),
                                    Color.clear,
                                    Color.blue.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: -4)
                    .padding(.horizontal, 4)
                    .layoutPriority(1)
            }
            .navigationTitle("Preview")
            .onAppear { showCursor = true }
        }
        .tint(.accentColor)
    }

    private var hostArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Host Input Preview")
                    .font(.headline)
                Spacer()
                Button("Copy") {
                    UIPasteboard.general.string = clipboardText
                }
                .buttonStyle(.bordered)
                Button("Clear") {
                    clipboardText = ""
                    UIPasteboard.general.string = ""
                }
                .buttonStyle(.borderedProminent)
            }

            hostTextPreview
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private var hostTextPreview: some View {
        ScrollViewReader { proxy in
            ScrollView {
                HostPreviewText(text: clipboardText, showCursor: showCursor)

                Color.clear
                    .frame(height: 1)
                    .id("host-text-bottom")
            }
            .frame(maxWidth: .infinity)
            .frame(height: hostTextHeight)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scrollIndicators(.visible)
            .onTapGesture {
                hostInputFocusRevision &+= 1
            }
            .onChange(of: clipboardText) { _, _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("host-text-bottom", anchor: .bottom)
                }
            }
        }
    }
}

private struct HostPreviewText: View {
    let text: String
    let showCursor: Bool

    private var isEmpty: Bool {
        text.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isEmpty ? "Nothing inserted yet. Try typing on the keyboard below." : text)
                .font(.body)
                .foregroundStyle(isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            if !isEmpty {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 20)
                    .opacity(showCursor ? 1 : 0)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(12)
    }
}

struct PreviewView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewView()
    }
}
