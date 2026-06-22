//
//  AppGroup.swift
//  VerseFinderApp
//
//  Created by Assistant on 2026/03/05.
//

import Foundation

/// Centralized access to the shared App Group container used by
/// both the main app and the keyboard extension.
///
/// The suite identifier is looked up from Info.plist under key
/// `AppGroupIdentifier`. If missing, a reasonable placeholder is used.
/// Make sure to set this key in both the app and extension targets and
/// entitlements to the same value.
public enum AppGroup {
    /// Info.plist key used to read the App Group identifier.
    private static let infoPlistKey = "AppGroupIdentifier"

    /// Fallback identifier if the Info.plist key is not set.
    /// Replace with your actual identifier and ensure entitlements match.
    private static let fallbackIdentifier = "group.com.maphari.versekey"

    /// The resolved App Group identifier.
    public static var identifier: String {
        if let id = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String, !id.isEmpty {
            return id
        }
        return fallbackIdentifier
    }

    /// Shared UserDefaults scoped to the App Group.
    public static var defaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: identifier) else {
            // If suite cannot be created, fall back to standard (non-shared)
            // to avoid crashes in development builds.
            return .standard
        }
        return defaults
    }

    /// The shared container URL for storing small JSON files (e.g., history).
    public static var containerURL: URL {
        let fm = FileManager.default
        if let url = fm.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        // Development fallback to documents directory
        return fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}
