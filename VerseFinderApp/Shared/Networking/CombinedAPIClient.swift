//
//  CombinedAPIClient.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/03.
//

import Foundation

/// Combined API client that tries real APIs first with SimpleClient as fallback
nonisolated public struct CombinedAPIClient: VerseAPIClient {
    private let bibleAPIClient: BibleAPIClient
    private let apiBibleComClient: APIBibleComClient
    private let youVersionClient: YouVersionAPIClient
    private let esvClient: ESVAPIClient
    private let simpleClient: SimpleVerseAPIClient
    
    // Use strict routing without fallback between real APIs
    private let apiPreference: [Translation: APISource] = [
        // Public domain -> bible-api.com; avoids requiring API.Bible credentials
        .kjv: .bibleAPI,
        .asv: .bibleAPI,
        .web: .bibleAPI,
        .bbe: .bibleAPI,
        .webbe: .bibleAPI,

        // YouVersion credentials currently authorize these translations
        .niv: .youVersion,
        .amp: .youVersion,
        .nasb1995: .youVersion,

        // API.Bible licensed translations; require a valid API.Bible key
        .csb: .apiBibleCom,
        .nkjv: .apiBibleCom,
        .nlt: .apiBibleCom,
        .msg: .apiBibleCom,

        // YouVersion-only per user access
        .nasb2020: .youVersion,
        .webus: .apiBibleCom,
        .nirv: .youVersion,
        .easy: .youVersion,
        .tpt: .youVersion,

        // ESV via esvapi.org
        .esv: .esv
    ]
    
    private enum APISource {
        case bibleAPI
        case apiBibleCom
        case youVersion
        case esv
        case simple
    }
    
    public init() {
        self.bibleAPIClient = BibleAPIClient()
        self.apiBibleComClient = APIBibleComClient()
        self.youVersionClient = YouVersionAPIClient()
        self.esvClient = ESVAPIClient() // reads token from Info.plist
        self.simpleClient = SimpleVerseAPIClient()
    }
    
    public func fetch(reference: VerseReference, translation: Translation) async throws -> VerseText {
        let apiSource = apiPreference[translation] ?? .apiBibleCom
        do {
            switch apiSource {
            case .bibleAPI:
                let result = try await bibleAPIClient.fetch(reference: reference, translation: translation)
                return result
            case .apiBibleCom:
                let result = try await apiBibleComClient.fetch(reference: reference, translation: translation)
                return result
            case .youVersion:
                let result = try await youVersionClient.fetch(reference: reference, translation: translation)
                return result
            case .esv:
                let result = try await esvClient.fetch(reference: reference, translation: translation)
                return result
            case .simple:
                return try await simpleClient.fetch(reference: reference, translation: translation)
            }
        } catch {
            throw error
        }
    }
    
    /// Search verses by content across available APIs
    public func searchVerse(query: String, translation: Translation, limit: Int = 5) async throws -> [VerseText] {
        let apiSource = apiPreference[translation] ?? .apiBibleCom
        do {
            switch apiSource {
            case .bibleAPI:
                return try await bibleAPIClient.searchVerse(query: query, translation: translation, limit: limit)
            case .apiBibleCom:
                return try await apiBibleComClient.searchVerse(query: query, translation: translation, limit: limit)
            case .youVersion:
                return try await youVersionClient.searchVerse(query: query, translation: translation, limit: limit)
            case .esv:
                // ESV API does not support full-text search; return [] to signal "no results"
                return try await esvClient.searchVerse(query: query, translation: translation, limit: limit)
            case .simple:
                return try await simpleClient.searchVerse(query: query, translation: translation, limit: limit)
            }
        } catch {
            throw error
        }
    }

    /// Search verses across ALL translations that support full-text search, returning combined results
    public func searchVerseAcrossTranslations(query: String, limit: Int = 10) async throws -> [VerseText] {
        // Translations with real full-text search capability
        let searchableTranslations: [Translation] = [
            .nlt, .csb, .nkjv, .msg,          // APIBibleCom
            .niv, .amp, .nasb1995, .nasb2020,   // YouVersion
            .nirv, .easy, .tpt,                 // YouVersion
            .kjv, .asv, .web                    // BibleAPI (limited but included)
        ]

        var allResults: [VerseText] = []

        await withTaskGroup(of: [VerseText].self) { group in
            for translation in searchableTranslations {
                group.addTask { [self] in
                    do {
                        let results = try await self.searchVerse(query: query, translation: translation, limit: limit)
                        return results
                    } catch {
                        return []
                    }
                }
            }
            for await results in group {
                allResults.append(contentsOf: results)
            }
        }

        // Deduplicate by reference (keep first occurrence which is typically most relevant)
        var seen = Set<String>()
        var deduplicated: [VerseText] = []
        for verse in allResults {
            let key = "\(verse.reference.book) \(verse.reference.chapter):\(verse.reference.startVerse)"
            if seen.insert(key).inserted {
                deduplicated.append(verse)
            }
        }

        return deduplicated
    }
    
    /// Handle complex verse patterns like "john 1:2,4-6,7"
    public func fetchComplexVerses(_ input: String, translation: Translation) async throws -> [VerseText] {
        do {
            let references = try VerseParser.parseComplexVerses(input)
            var results: [VerseText] = []
            for reference in references {
                let verse = try await fetch(reference: reference, translation: translation)
                results.append(verse)
            }
            return results
        } catch {
            throw error
        }
    }
    
    public func fetchChapter(book: String, chapter: Int, translation: Translation) async throws -> VerseText {
        let reference = VerseReference(book: book, chapter: chapter, startVerse: 1, endVerse: 999)
        return try await fetch(reference: reference, translation: translation)
    }

    public func fetchChapterVerseCount(book: String, chapter: Int) async throws -> Int {
        do {
            return try await apiBibleComClient.getChapterVerseCount(book: book, chapter: chapter)
        } catch {
            return try await bibleAPIClient.fetchChapterVerseCount(book: book, chapter: chapter)
        }
    }

    public func fetchSelectedVerses(book: String, chapter: Int, verses: [Int], translation: Translation) async throws -> VerseText {
        let uniqueSorted = Array(Set(verses)).sorted()
        guard !uniqueSorted.isEmpty else {
            throw APIError.emptyResponse
        }
        var combinedTextParts: [String] = []
        for v in uniqueSorted {
            let ref = VerseReference(book: book, chapter: chapter, startVerse: v, endVerse: v)
            let verseText = try await fetch(reference: ref, translation: translation)
            combinedTextParts.append(verseText.text)
        }
        let combinedText = combinedTextParts.joined(separator: "\n")
        let aggregateRef = VerseReference(book: book, chapter: chapter, startVerse: uniqueSorted.first ?? 1, endVerse: uniqueSorted.last ?? (uniqueSorted.first ?? 1))
        return VerseText(reference: aggregateRef, translation: translation, text: combinedText)
    }
}

/// Protocol extension to add search capabilities
public protocol SearchableVerseAPIClient: VerseAPIClient {
    func searchVerse(query: String, translation: Translation, limit: Int) async throws -> [VerseText]
}

// MARK: - Protocol Conformances
extension BibleAPIClient: SearchableVerseAPIClient {}
extension YouVersionAPIClient: SearchableVerseAPIClient {}
extension CombinedAPIClient: SearchableVerseAPIClient {}
