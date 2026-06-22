//
//  VerseFinderApp.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/03.
//

import SwiftUI
import UIKit

@main
struct VerseFinderApp: App {
    // Removed AppDelegate to avoid Info.plist conflicts
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(OptimizedAppServices.shared)
                .onAppear {
                    // Configure app settings programmatically to avoid Info.plist conflicts
                    configureAppSettings()
                    setupMemoryWarnings()
                }
        }
    }
    
    private func configureAppSettings() {
        // Configure network security programmatically
        // This avoids potential Info.plist conflicts
        
        // Set up URLSession configuration with proper security
        let config = URLSessionConfiguration.default
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        
        // Skip audio configuration completely to avoid sandbox violations
        print("✅ App configured successfully (no audio session needed)")
    }
    
    private func setupMemoryWarnings() {
        // Set up memory warning handling without AppDelegate
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            MemoryManager.performMemoryCleanup()
            print("⚠️ Memory warning - performed cleanup")
        }
    }
}

// MARK: - ContentView Placeholder
struct ContentView: View {
    @EnvironmentObject var appServices: OptimizedAppServices
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Enter verse reference (e.g., John 3:16)", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("Search") {
                    Task {
                        do {
                            let reference = try appServices.parseReference(searchText)
                            await appServices.fetchVerse(reference: reference, translation: .kjv)
                        } catch {
                            await MainActor.run {
                                appServices.errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
                .padding()
                
                if appServices.isLoading {
                    ProgressView("Loading...")
                }
                
                if let verse = appServices.currentVerse {
                    ScrollView {
                        Text(verse.text)
                            .padding()
                    }
                }
                
                if let error = appServices.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
                
                // Memory status for debugging
                Text("Memory: \(getMemoryUsage())")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .navigationTitle("Verse Finder")
        }
    }
    
    private func getMemoryUsage() -> String {
        let (usage, isHigh) = appServices.getMemoryStatus()
        let mb = usage / 1024 / 1024
        return "\(mb)MB \(isHigh ? "⚠️" : "✅")"
    }
}