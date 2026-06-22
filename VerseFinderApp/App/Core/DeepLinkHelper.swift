import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum DeepLinkHelper {
    /// Attempts to open iOS Keyboard settings. iOS does not expose a public URL for the
    /// VerseKey full-access subpage, so this falls back to the app settings page.
    static func openKeyboardSettings() {
        #if canImport(UIKit)
        let targets = [
            URL(string: "App-Prefs:root=General&path=Keyboard"),
            URL(string: "App-prefs:root=General&path=Keyboard"),
            URL(string: "prefs:root=General&path=Keyboard")
        ].compactMap { $0 }

        openFirstAvailableURL(targets, fallback: openAppSettings)
        #endif
    }

    /// Attempts to open the app's Settings page. Uses reflection to avoid direct UIApplication.shared references
    /// so this compiles in app extensions as well. In extensions, this will usually no-op at runtime.
    static func openAppSettings() {
        #if canImport(UIKit)
        // Prefer standard settings URL if available via reflection
        var targets: [URL] = []
        if let settingsURLString = (NSClassFromString("UIApplication") as AnyObject?)?.value(forKey: "openSettingsURLString") as? String,
           let u = URL(string: settingsURLString) {
            targets.append(u)
        }
        // Fallback private schemes (may be blocked by the system; best-effort only)
        if let u = URL(string: "App-Prefs:root") { targets.append(u) }
        if let u = URL(string: "prefs:root") { targets.append(u) }
        if let u = URL(string: "App-prefs:root") { targets.append(u) }

        openFirstAvailableURL(targets)
        #endif
    }

    private static func openFirstAvailableURL(_ targets: [URL], fallback: (() -> Void)? = nil) {
        for url in targets {
            if openURLViaUIApplication(url) { return }
        }
        fallback?()
    }

    /// Uses Objective-C runtime to call sharedApplication/canOpenURL/openURL without referencing
    /// UIApplication.shared directly (to keep this extension-safe at compile time).
    @discardableResult
    private static func openURLViaUIApplication(_ url: URL) -> Bool {
        #if canImport(UIKit)
        guard let uiAppClass: AnyObject = NSClassFromString("UIApplication"),
              uiAppClass.responds(to: NSSelectorFromString("sharedApplication")),
              let sharedUnmanaged = uiAppClass.perform(NSSelectorFromString("sharedApplication")),
              let app = sharedUnmanaged.takeUnretainedValue() as? NSObject else { return false }

        let canOpenSel = NSSelectorFromString("canOpenURL:")
        let openSel = NSSelectorFromString("openURL:")

        var canOpen = true
        if app.responds(to: canOpenSel) {
            if let result = app.perform(canOpenSel, with: url)?.takeUnretainedValue() as? Bool {
                canOpen = result
            }
        }
        if canOpen {
            _ = app.perform(openSel, with: url)
            return true
        }
        return false
        #else
        return false
        #endif
    }
}
