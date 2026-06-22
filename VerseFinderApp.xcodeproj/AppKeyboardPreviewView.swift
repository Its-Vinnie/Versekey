import SwiftUI
import Foundation

struct AppClipboardInserter {
    func insert(_ text: String) { UIPasteboard.general.string = text }
}

struct AppKeyboardPreviewView: View {
    @State private var query: String = "John 3:16"
    @State private var isLoading: Bool = false
    @State private var error: String? = nil
    @State private var selected: Translation = .kjv
    @State private var format: InsertFormat = .textAndReference
    @State private var preview: String? = nil

    private let service = VerseService(api: StubAPIClient())
    private let formatter = InsertFormatter()
    private let inserter = AppClipboardInserter()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Reference", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(action: search) {
                    if isLoading { ProgressView() } else { Image(systemName: "magnifyingglass") }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Translation.allCases, id: \.self) { t in
                        Button(action: { selected = t }) {
                            Text(t.rawValue.uppercased())
                                .font(.caption)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(selected == t ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            Picker("Format", selection: $format) {
                ForEach(InsertFormat.allCases, id: \.self) { f in
                    Text(label(for: f)).tag(f)
                }
            }
            .pickerStyle(.segmented)

            Group {
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
                else if isLoading { Text("Loading...").font(.caption) }
                else if let preview { Text(preview).font(.footnote) }
            }

            HStack {
                Button("Insert (Copy)") {
                    if let preview { inserter.insert(preview) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(preview == nil)

                Spacer()
            }
        }
        .padding()
        .navigationTitle("Keyboard Preview")
    }

    private func search() {
        error = nil
        preview = nil
        isLoading = true
        Task {
            do {
                let ref = try VerseParser.parse(query)
                let verse = try await service.getVerse(reference: ref, translation: selected)
                await MainActor.run {
                    preview = formatter.format(verse, as: format)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
                    self.isLoading = false
                }
            }
        }
    }

    private func label(for format: InsertFormat) -> String {
        switch format {
        case .textOnly: return "Text only"
        case .textAndReference: return "Text + Ref"
        case .referenceOnly: return "Ref only"
        }
    }
}

#Preview {
    NavigationStack { AppKeyboardPreviewView() }
}
