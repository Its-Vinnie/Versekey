//
//  OptimizedAppServices.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/03.
//

import Foundation
import Combine

/// Optimized app services that prevent memory issues and sandbox violations
@MainActor
public class OptimizedAppServices: ObservableObject {
    private let apiClient: MemoryOptimizedAPIClient
    private let insertFormatter = InsertFormatter()
    
    @Published public var currentVerse: VerseText?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    public init() {
        self.apiClient = MemoryOptimizedAPIClient()
        
        // Skip audio configuration completely to avoid sandbox violations
        print("✅ App services initialized without audio session")
    }
    
    deinit {
        // Perform memory cleanup only
        MemoryManager.performMemoryCleanup()
    }
    
    /// Fetch verse with memory monitoring
    public func fetchVerse(reference: VerseReference, translation: Translation) async {
        // Check memory before heavy operation
        if MemoryManager.isMemoryUsageHigh() {
            MemoryManager.performMemoryCleanup()
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let verse = try await apiClient.fetch(reference: reference, translation: translation)
            
            await MainActor.run {
                currentVerse = verse
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
        
        // Clean up after operation if memory is getting high
        if MemoryManager.isMemoryUsageHigh() {
            MemoryManager.performMemoryCleanup()
        }
    }
    
    /// Parse verse reference safely
    public func parseReference(_ input: String) throws -> VerseReference {
        return try VerseParser.parse(input)
    }
    
    /// Format verse for insertion
    public func formatVerse(_ verse: VerseText, as format: InsertFormat) -> String {
        return insertFormatter.format(verse, as: format)
    }
    
    /// Monitor memory usage
    public func getMemoryStatus() -> (usage: UInt64, isHigh: Bool) {
        let usage = MemoryManager.getCurrentMemoryUsage()
        let isHigh = MemoryManager.isMemoryUsageHigh()
        return (usage, isHigh)
    }
    
    /// Force cleanup when needed
    public func performCleanup() {
        MemoryManager.performMemoryCleanup()
    }
}

// MARK: - Singleton Pattern for Global Access
public extension OptimizedAppServices {
    static let shared = OptimizedAppServices()
}