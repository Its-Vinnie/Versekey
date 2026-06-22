//
//  BibleAPIClient.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/03.
//

import Foundation

/// Simple and reliable Bible API client using bible-api.com
nonisolated public struct BibleAPIClient: VerseAPIClient {
    private let session: URLSession
    private let baseURL = "https://bible-api.com"  // Simple, reliable Bible API
    private let supportedTranslations: Set<Translation> = [.kjv, .asv, .web, .bbe, .webbe]

    public init(apiKey: String = "", session: URLSession = .shared) {
        // bible-api.com doesn't need an API key
        self.session = session
    }
    
    public func fetch(reference: VerseReference, translation: Translation) async throws -> VerseText {
        // Fast-path: if translation isn't supported by bible-api.com, signal to switch
        guard supportedTranslations.contains(translation) else {
            throw APIError.unsupportedTranslation
        }
        
        // Try primary API first
        do {
            return try await fetchFromPrimaryAPI(reference: reference, translation: translation)
        } catch {
            print("❌ Primary Bible API failed, trying fallback...")
            return try await fetchFromFallbackAPI(reference: reference, translation: translation)
        }
    }
    
    private func fetchFromPrimaryAPI(reference: VerseReference, translation: Translation) async throws -> VerseText {
        // Use bible-api.com format which is simple and reliable
        let referenceString = "\(reference.book) \(reference.chapter):\(reference.startVerse)"
        let encodedReference = referenceString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? referenceString
        let urlString = "\(baseURL)/\(encodedReference)?translation=\(translation.rawValue)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("VerseFinderApp/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0
        
        print("🔵 Primary Bible API Request: \(url.absoluteString)")
        print("📡 Attempting to connect to hostname: \(url.host ?? "unknown")")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📊 Primary Bible API Response Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Primary Bible API Error Response: \(responseString)")
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        // Parse bible-api.com response format
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = json?["text"] as? String else {
            throw APIError.decodingError
        }
        
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        print("✅ Primary Bible API Success: Fetched \(reference.book) \(reference.chapter):\(reference.startVerse)")
        
        return VerseText(
            reference: reference,
            translation: translation,
            text: cleanText
        )
    }
    
    private func fetchFromFallbackAPI(reference: VerseReference, translation: Translation) async throws -> VerseText {
        // Use multiple fallback endpoints
        let referenceString = "\(reference.book)+\(reference.chapter):\(reference.startVerse)"
        let encodedReference = referenceString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? referenceString
        
        // Try multiple fallback endpoints
        let fallbackEndpoints = [
            "https://labs.bible.org/api/?passage=\(encodedReference)&type=json",
            "https://bible-api.com/\(encodedReference)",
            "https://getbible.net/json?passage=\(encodedReference)"
        ]
        
        for endpoint in fallbackEndpoints {
            do {
                guard let url = URL(string: endpoint) else { continue }
                
                var request = URLRequest(url: url)
                request.setValue("VerseFinderApp/1.0", forHTTPHeaderField: "User-Agent")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 10.0
                
                print("🔄 Trying fallback API: \(url.absoluteString)")
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    print("❌ Fallback endpoint failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                    continue
                }
                
                // Try to parse different API response formats
                if let text = try? parseAPIResponse(data: data, from: endpoint) {
                    print("✅ Fallback API success from: \(url.host ?? "unknown")")
                    return VerseText(
                        reference: reference,
                        translation: translation,
                        text: text.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            } catch {
                print("❌ Fallback endpoint error: \(error.localizedDescription)")
                continue
            }
        }
        
        // If all fallbacks fail, throw an error
        throw APIError.networkError(NSError(domain: "BibleAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "All fallback APIs failed"]))
    }
    
    private func parseAPIResponse(data: Data, from endpoint: String) throws -> String {
        // Handle different API response formats
        let json = try JSONSerialization.jsonObject(with: data)
        
        if let dict = json as? [String: Any] {
            // bible-api.com format
            if let text = dict["text"] as? String {
                return text
            }
            // Other formats
            if let verses = dict["verses"] as? [[String: Any]], let firstVerse = verses.first {
                if let text = firstVerse["text"] as? String {
                    return text
                }
            }
        } else if let array = json as? [[String: Any]], let firstItem = array.first {
            // labs.bible.org format
            if let text = firstItem["text"] as? String {
                return text
            }
        }
        
        throw APIError.decodingError
    }
    
    public func searchVerse(query: String, translation: Translation, limit: Int = 5) async throws -> [VerseText] {
        guard supportedTranslations.contains(translation) else {
            throw APIError.unsupportedTranslation
        }
        
        // Simple search using the same endpoint
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/\(encodedQuery)?translation=\(translation.rawValue)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("VerseFinderApp/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = json?["text"] as? String,
              let reference = json?["reference"] as? String else {
            throw APIError.decodingError
        }
        
        // Parse reference to create VerseReference
        if let parsedRef = try? VerseParser.parse(reference) {
            return [VerseText(
                reference: parsedRef,
                translation: translation,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines)
            )]
        }
        
        return []
    }

    public func fetchChapterVerseCount(book: String, chapter: Int) async throws -> Int {
        let referenceString = "\(book) \(chapter)"
        let encodedReference = referenceString.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? referenceString
        guard let url = URL(string: "\(baseURL)/\(encodedReference)?translation=kjv") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("VerseFinderApp/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let verses = json?["verses"] as? [[String: Any]], !verses.isEmpty {
            return verses.count
        }

        throw APIError.decodingError
    }
}

// MARK: - Enhanced Error Types

nonisolated public enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case networkError(Error)
    case noInternetConnection
    case requestTimeout
    case emptyResponse
    case unsupportedTranslation
    case authenticationFailed
    case rateLimitExceeded
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            switch code {
            case 401:
                return "API authentication failed. Please check your API key."
            case 403:
                return "This translation is not enabled for the configured API key."
            case 404:
                return "Verse or passage not found."
            case 408:
                return "Request timed out. Please try again."
            case 429:
                return "API rate limit exceeded. Please try again later."
            case 500...599:
                return "The Bible service is temporarily unavailable. Please try again."
            default:
                return "Server error (code \(code))"
            }
        case .decodingError:
            return "Failed to decode verse data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noInternetConnection:
            return "No internet connection available"
        case .requestTimeout:
            return "Request timed out. Please try again."
        case .emptyResponse:
            return "No verse content found"
        case .unsupportedTranslation:
            return "Translation not supported by this API"
        case .authenticationFailed:
            return "API authentication failed. Please check your API key."
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        }
    }
}

// Backward compatibility aliases
public typealias GlobalAPIError = APIError
extension BibleAPIClient {
    // Allow references to BibleAPIClient.APIError to resolve to the global APIError
    public typealias APIError = GlobalAPIError
}
