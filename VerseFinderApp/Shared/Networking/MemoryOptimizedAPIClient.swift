//
//  MemoryOptimizedAPIClient.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/03.
//

import Foundation
import AVFoundation

/// Memory-optimized API client that prevents memory leaks and reduces footprint
public actor MemoryOptimizedAPIClient: VerseAPIClient {
    private var session: URLSession?
    private let cache = LimitedCache<String, VerseText>(maxSize: 50) // Limit cache size
    
    public init() {
        // Use a lightweight session configuration
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil // Disable URL cache to save memory
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        config.httpMaximumConnectionsPerHost = 2 // Limit connections
        
        self.session = URLSession(configuration: config)
    }
    
    deinit {
        session?.invalidateAndCancel()
    }
    
    public func fetch(reference: VerseReference, translation: Translation) async throws -> VerseText {
        let cacheKey = "\(reference.book)_\(reference.chapter)_\(reference.startVerse)_\(translation.rawValue)"
        
        // Check cache first - use await since cache is an actor
        if let cached = await cache.getValue(for: cacheKey) {
            return cached
        }
        
        // Use the combined client but with memory optimizations
        let combinedClient = CombinedAPIClient()
        let result = try await combinedClient.fetch(reference: reference, translation: translation)
        
        // Cache the result - use await since cache is an actor
        await cache.setValue(result, for: cacheKey)
        
        return result
    }
}

// MARK: - Limited Cache Implementation
/// A simple cache with size limits to prevent memory bloat
private actor LimitedCache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]
    private var accessOrder: [Key] = []
    private let maxSize: Int
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func setValue(_ value: Value, for key: Key) {
        // Remove existing entry if present
        if storage[key] != nil {
            accessOrder.removeAll { $0 == key }
        }
        
        // Add new entry
        storage[key] = value
        accessOrder.append(key)
        
        // Enforce size limit
        while storage.count > maxSize {
            if let oldestKey = accessOrder.first {
                storage.removeValue(forKey: oldestKey)
                accessOrder.removeFirst()
            }
        }
    }
    
    func getValue(for key: Key) -> Value? {
        guard let value = storage[key] else { return nil }
        
        // Update access order
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        
        return value
    }
    
    func clear() {
        storage.removeAll()
        accessOrder.removeAll()
    }
}

// MARK: - Memory Management Utilities
nonisolated public class MemoryManager {
    /// Force memory cleanup
    public static func performMemoryCleanup() {
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()
        
        // Trigger garbage collection
        autoreleasepool {
            // This block helps release temporary objects
        }
    }
    
    /// Monitor memory usage
    public static func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    /// Check if memory usage is approaching limits
    public static func isMemoryUsageHigh() -> Bool {
        let currentUsage = getCurrentMemoryUsage()
        let limitMB: UInt64 = 70 * 1024 * 1024 // 70MB threshold (below the 77MB limit)
        return currentUsage > limitMB
    }
}

// MARK: - Audio Session Fix
/// Helper to safely avoid AVAudioSession sandbox violations
public class AudioSessionManager {
    /// Configure audio session safely - DISABLED to prevent sandbox violations
    public static func configureSafely() {
        // DISABLED: For a Bible text app, we don't need audio session at all
        // This prevents sandbox violations entirely
        
        print("✅ Audio session configuration skipped (not needed for text app)")
    }
    
    /// Deactivate audio session - DISABLED  
    public static func deactivate() {
        // DISABLED: No audio session to deactivate
        print("✅ Audio session deactivation skipped")
    }
}
