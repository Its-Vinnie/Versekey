//
//  ESVAPIClient.swift
//  VerseFinderApp
//
//  Created by Assistant on 2026/03/07.
//

import Foundation

/// Client for https://api.esv.org/v3/passage/text/ (ESV)
nonisolated public struct ESVAPIClient: VerseAPIClient {
    private let session: URLSession
    private let token: String
    private let baseURL = URL(string: "https://api.esv.org/v3/passage/text/")!

    public init(session: URLSession = .shared, token: String? = nil) {
        // Read token from Info.plist key "ESVAPIToken" unless explicitly provided
        if let provided = token, !provided.isEmpty {
            self.token = Self.normalizedToken(provided)
        } else if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "ESVAPIToken") as? String, !fromPlist.isEmpty {
            self.token = Self.normalizedToken(fromPlist)
        } else {
            self.token = ""
        }
        self.session = session
    }

    private static func normalizedToken(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: #"(?i)^\s*Token\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func fetch(reference: VerseReference, translation: Translation) async throws -> VerseText {
        guard translation == .esv else { throw APIError.unsupportedTranslation }
        guard !token.isEmpty else { throw APIError.authenticationFailed }

        let q = passageQuery(from: reference)
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "include-passage-references", value: "false"),
            URLQueryItem(name: "include-verse-numbers", value: "true"),
            URLQueryItem(name: "include-first-verse-number", value: "true"),
            URLQueryItem(name: "include-footnotes", value: "false"),
            URLQueryItem(name: "include-headings", value: "false"),
            URLQueryItem(name: "include-short-copyright", value: "false"),
            URLQueryItem(name: "line-length", value: "0")
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 404 {
            throw VerseParseError.verseNotFound("Verse or passage not found for \(reference.book) \(reference.chapter)")
        }
        guard http.statusCode == 200 else { throw APIError.httpError(http.statusCode) }

        struct ESVResponse: Decodable {
            let passages: [String]?
        }
        let decoded = try JSONDecoder().decode(ESVResponse.self, from: data)
        let text = decoded.passages?.joined(separator: "\n\n") ?? ""
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return VerseText(reference: reference, translation: translation, text: cleaned)
    }

    private func passageQuery(from ref: VerseReference) -> String {
        if let end = ref.endVerse {
            if end == 999 {
                // whole chapter: "Book Chapter"
                return "\(ref.book) \(ref.chapter)"
            } else {
                // range: "Book Chapter:Start-End"
                return "\(ref.book) \(ref.chapter):\(ref.startVerse)-\(end)"
            }
        } else {
            // single: "Book Chapter:Verse"
            return "\(ref.book) \(ref.chapter):\(ref.startVerse)"
        }
    }
}

// Optional: provide a no-op search to satisfy CombinedAPIClient.search routing
extension ESVAPIClient: SearchableVerseAPIClient {
    public func searchVerse(query: String, translation: Translation, limit: Int) async throws -> [VerseText] {
        // ESV Passage Text API does not offer text search; return empty results.
        return []
    }
}
