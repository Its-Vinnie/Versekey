//
//  RobustAPIClient.swift  
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/03.
//

import Foundation

/// Robust API client with fallback and retry capabilities
nonisolated public struct RobustAPIClient: VerseAPIClient {
    private let primaryClient: BibleAPIClient
    private let fallbackClient: StubAPIClient
    private let maxRetries: Int
    
    public init(maxRetries: Int = 5) {
        self.primaryClient = BibleAPIClient()
        self.fallbackClient = StubAPIClient()
        self.maxRetries = maxRetries
    }
    
    public func fetch(reference: VerseReference, translation: Translation) async throws -> VerseText {
        // Try the real API first with retries
        for attempt in 0..<maxRetries {
            do {
                let result = try await primaryClient.fetch(reference: reference, translation: translation)
                return result
            } catch {
                // On last attempt or for certain errors, don't retry
                if attempt == maxRetries - 1 || shouldNotRetry(error: error) {
                    // For demo purposes, fall back to stub data with a notice
                    print("API failed after \(maxRetries) attempts: \(error.localizedDescription)")
                    print("Falling back to demo content...")
                    
                    let stubResult = try await fallbackClient.fetch(reference: reference, translation: translation)
                    return VerseText(
                        reference: reference,
                        translation: translation,
                        text: "[DEMO] \(stubResult.text) \n\n⚠️ Using demo content - real verses will load when connected."
                    )
                }
                
                // Wait before retry (exponential backoff)
                let delay = Double(attempt + 1) * 0.5
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // This shouldn't be reached, but provide fallback
        throw NSError(domain: "RobustAPIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"])
    }
    
    private func shouldNotRetry(error: Error) -> Bool {
        // Don't retry on certain errors
        if error is VerseParseError {
            return true  // Parse errors won't be fixed by retrying
        }
        
        // Check for specific error messages that indicate non-retryable errors
        let errorMessage = error.localizedDescription.lowercased()
        if errorMessage.contains("invalid") || errorMessage.contains("unknown") {
            return true
        }
        
        return false
    }
}
