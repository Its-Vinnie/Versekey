import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    private let allTranslations = Translation.allCases

    var body: some View {
        NavigationStack {
            Form {
                Section("Translations") {
                    // Multi-select visible translations
                    NavigationLink("Select Translation Visibility") { TranslationSelectionView(settings: settings, allTranslations: allTranslations) }
                    Picker("Default Translation", selection: Binding<Translation>(
                        get: {
                            Translation(rawValue: settings.defaultTranslation.lowercased()) ?? .kjv
                        },
                        set: { newValue in
                            settings.defaultTranslation = newValue.rawValue
                        }
                    )) {
                        ForEach(allTranslations, id: \.self) { t in
                            Text(t.displayCode).tag(t)
                        }
                    }
                }

                Section("Insert Format") {
                    Picker("Format", selection: Binding<String>(
                        get: { settings.insertFormat.rawValue },
                        set: { raw in settings.insertFormat = SettingsStore.InsertFormat(rawValue: raw) ?? .textAndReference }
                    )) {
                        ForEach(SettingsStore.InsertFormat.allCases, id: \.self) { f in
                            Text(label(for: f)).tag(f.rawValue)
                        }
                    }
                }

                Section("Preview Length") {
                    Picker("Length", selection: $settings.previewLength) {
                        Text("Short").tag(120)
                        Text("Medium").tag(180)
                        Text("Long").tag(260)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Haptics & Glow") {
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                    Picker("Glow Intensity", selection: $settings.glowIntensity) {
                        Text("Low").tag(0.3)
                        Text("Medium").tag(0.6)
                        Text("High").tag(0.9)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button("Reset Onboarding") { settings.didCompleteOnboarding = false }
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func label(for f: SettingsStore.InsertFormat) -> String {
        switch f {
        case .textOnly: return "Text only"
        case .textAndReference: return "Text + Reference"
        case .referenceOnly: return "Reference only"
        }
    }
}

private struct TranslationSelectionView: View {
    @ObservedObject var settings: SettingsStore
    let allTranslations: [Translation]

    var body: some View {
        List {
            ForEach(Array(allTranslations), id: \.self) { (t: Translation) in
                let code = t.rawValue.uppercased()
                HStack {
                    Text(t.displayCode)
                    Spacer()
                    if settings.translationsShown.contains(code) {
                        Image(systemName: "checkmark").foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    var shown = settings.translationsShown
                    if let idx = shown.firstIndex(of: code) { shown.remove(at: idx) } else { shown.append(code) }
                    settings.translationsShown = shown
                }
            }
        }
        .navigationTitle("Visible Translations")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settings: SettingsStore())
    }
}
