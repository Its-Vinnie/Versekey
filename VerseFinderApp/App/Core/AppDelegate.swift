//
//  AppDelegate.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/03.
//

import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupMemoryWarningHandling()
        return true
    }
    
    private func setupMemoryWarningHandling() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Perform aggressive cleanup when system sends memory warning
            MemoryManager.performMemoryCleanup()
            
            // Clear any unnecessary cached data
            URLCache.shared.removeAllCachedResponses()
            
            print("Memory warning received - performed cleanup")
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Deactivate audio session when going to background
        AudioSessionManager.deactivate()
        
        // Perform cleanup when app goes to background
        MemoryManager.performMemoryCleanup()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Final cleanup
        AudioSessionManager.deactivate()
        MemoryManager.performMemoryCleanup()
        
        // Remove observers
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Scene Delegate
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Create window with minimal memory footprint
        window = UIWindow(windowScene: windowScene)
        
        // Set up your SwiftUI root view here
        // window?.rootViewController = UIHostingController(rootView: ContentView())
        window?.makeKeyAndVisible()
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Cleanup when scene goes to background
        MemoryManager.performMemoryCleanup()
    }
}
