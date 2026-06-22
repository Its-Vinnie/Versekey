import Combine
import SwiftUI

// Lightweight preview inserter for the main app to host the KeyboardView.
// This conforms to the expected InsertPipeline API used by the keyboard.
@MainActor
private final class PreviewInserter: ObservableObject, InsertPipeline {
    @Published var text: String = UIPasteboard.general.string ?? ""

    @MainActor
    func insert(_ text: String) {
        let updated = self.text + text
        self.text = updated
        UIPasteboard.general.string = updated
    }

    @MainActor
    func deleteBackward() {
        var current = self.text
        if !current.isEmpty {
            current.removeLast()
            self.text = current
            UIPasteboard.general.string = current
        }
    }

    @MainActor
    func moveCursor(by offset: Int) {
        // No-op in preview host; clipboard has no cursor semantics
    }
    @MainActor
    func setPassiveMode(_ passive: Bool) {
        // No-op in preview host; in a real host this would control routing to the app vs. search field
    }
}

public struct AppKeyboardPreviewView: View {
    @StateObject private var inserter = PreviewInserter()
    @StateObject private var appearanceStore = KeyboardAppearanceStore()
    @State private var keyboardFrameHeight: CGFloat = 260
    @Binding private var hostInputFocusRevision: Int
    private let showHostArea: Bool
    private let onTextChange: (String) -> Void

    public init(
        showHostArea: Bool = true,
        hostInputFocusRevision: Binding<Int> = .constant(0),
        onTextChange: @escaping (String) -> Void = { _ in }
    ) {
        self.showHostArea = showHostArea
        self._hostInputFocusRevision = hostInputFocusRevision
        self.onTextChange = onTextChange
    }

    public var body: some View {
        let verticalSpacing: CGFloat = showHostArea ? 16 : 0
        let containerPadding: CGFloat = showHostArea ? 16 : 0

        VStack(spacing: verticalSpacing) {
            if showHostArea {
                Text("Verse Finder Keyboard Preview")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: CGFloat.infinity, alignment: .leading)

                Text("Type in the search bar above the keyboard or insert directly into the host using the on-screen keys. Insertions go to the clipboard in this preview.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: CGFloat.infinity, alignment: .leading)

                ScrollView {
                    // Non-editable host preview; typing must stay inside the custom keyboard.
                    Text(inserter.text.isEmpty ? "Inserted text appears here." : inserter.text)
                        .font(.body)
                        .foregroundStyle(inserter.text.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                )
                .scrollIndicators(.visible)
            }

            if showHostArea {
                Spacer(minLength: 0)
            }

            KeyboardView(
                inserter: inserter,
                suppressesSystemKeyboard: true,
                appearanceStore: appearanceStore
            )
                .frame(height: keyboardFrameHeight)
        }
        .padding(containerPadding)
        .navigationTitle("Keyboard Preview")
        .onChange(of: inserter.text) { _, text in
            onTextChange(text)
        }
        .onChange(of: hostInputFocusRevision) { _, _ in
            appearanceStore.notifyHostInputFocused()
        }
    }
}

struct AppKeyboardPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { AppKeyboardPreviewView() }
    }
}
