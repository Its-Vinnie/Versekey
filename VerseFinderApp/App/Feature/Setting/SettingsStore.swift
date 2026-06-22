//
//  SettingsStore.swift
//  VerseFinderApp
//
//  Created by Assistant on 2026/03/05.
//

import Foundation
import SwiftUI
import Combine

/// Shared settings model stored in the App Group so changes are visible
/// to both the main app and the keyboard extension.
///
/// This is intentionally lightweight and uses simple primitives that
/// serialize cleanly to UserDefaults.
public final class SettingsStore: ObservableObject {
    // MARK: - Keys
    private enum Keys: String { // raw keys for UserDefaults
        case didCompleteOnboarding
        case translationsShown // [String]
        case defaultTranslation // String
        case previewLength // Int (characters)
        case glowIntensity // Double 0...1
        case hapticsEnabled // Bool
        case insertFormat // String (enum rawValue)
    }

    // MARK: - Defaults
    public enum InsertFormat: String, CaseIterable, Identifiable {
        case textOnly
        case textAndReference
        case referenceOnly
        public var id: String { rawValue }
    }

    /// Reasonable default translations to show as tabs.
    /// Keep these values aligned with your Translation enum rawValues.
    public static let defaultTranslationsShown: [String] = ["NIV", "ESV", "KJV", "BBE"]

    /// Default preview length (Medium per PRD ~180 chars)
    public static let defaultPreviewLength: Int = 180

    /// Default glow intensity (mid value)
    public static let defaultGlowIntensity: Double = 0.6

    // MARK: - Published settings
    @Published public var didCompleteOnboarding: Bool {
        didSet { save(.didCompleteOnboarding, didCompleteOnboarding) }
    }

    @Published public var translationsShown: [String] {
        didSet { save(.translationsShown, translationsShown) }
    }

    @Published public var defaultTranslation: String {
        didSet { save(.defaultTranslation, defaultTranslation) }
    }

    @Published public var previewLength: Int {
        didSet { save(.previewLength, previewLength) }
    }

    @Published public var glowIntensity: Double {
        didSet { save(.glowIntensity, glowIntensity) }
    }

    @Published public var hapticsEnabled: Bool {
        didSet { save(.hapticsEnabled, hapticsEnabled) }
    }

    @Published public var insertFormat: InsertFormat {
        didSet { save(.insertFormat, insertFormat.rawValue) }
    }

    // MARK: - Init
    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        // Load initial values
        self.didCompleteOnboarding = defaults.bool(forKey: Keys.didCompleteOnboarding.rawValue)
        self.translationsShown = defaults.array(forKey: Keys.translationsShown.rawValue) as? [String] ?? Self.defaultTranslationsShown
        self.defaultTranslation = defaults.string(forKey: Keys.defaultTranslation.rawValue) ?? "NIV"
        let length = defaults.object(forKey: Keys.previewLength.rawValue) as? Int
        self.previewLength = length ?? Self.defaultPreviewLength
        let intensity = defaults.object(forKey: Keys.glowIntensity.rawValue) as? Double
        self.glowIntensity = intensity ?? Self.defaultGlowIntensity
        self.hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled.rawValue) as? Bool ?? true
        let rawFormat = defaults.string(forKey: Keys.insertFormat.rawValue) ?? InsertFormat.textAndReference.rawValue
        self.insertFormat = InsertFormat(rawValue: rawFormat) ?? .textAndReference
    }

    // MARK: - Private
    private let defaults: UserDefaults

    private func save(_ key: Keys, _ value: Any) {
        defaults.set(value, forKey: key.rawValue)
    }
}
