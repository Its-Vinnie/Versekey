//
//  VerseFinderAppApp.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/02.
//

import SwiftUI

@main
struct VerseFinderAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
