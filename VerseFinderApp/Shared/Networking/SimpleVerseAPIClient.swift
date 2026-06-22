//
//  SimpleVerseAPIClient.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/03.
//

import Foundation

/// Simple fallback API client with pre-loaded verse data for reliable testing
nonisolated public struct SimpleVerseAPIClient: VerseAPIClient {
    
    // Popular verses pre-loaded for instant access
    private let popularVerses: [String: String] = [
        "John 3:16": "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.",
        "John 3:17": "For God did not send his Son into the world to condemn the world, but to save the world through him.",
        "Romans 8:28": "And we know that in all things God works for the good of those who love him, who have been called according to his purpose.",
        "Philippians 4:13": "I can do all this through him who gives me strength.",
        "Jeremiah 29:11": "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.",
        "Psalm 23:1": "The Lord is my shepherd, I lack nothing.",
        "Isaiah 41:10": "So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you; I will uphold you with my righteous right hand.",
        "Matthew 28:19": "Therefore go and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit,",
        "Ephesians 2:8": "For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God—",
        "1 Corinthians 13:4": "Love is patient, love is kind. It does not envy, it does not boast, it is not proud.",
        "Proverbs 3:5": "Trust in the Lord with all your heart and lean not on your own understanding;",
        "Matthew 5:16": "In the same way, let your light shine before others, that they may see your good deeds and glorify your Father in heaven.",
        "Romans 10:9": "If you declare with your mouth, \"Jesus is Lord,\" and believe in your heart that God raised him from the dead, you will be saved.",
        "Galatians 2:20": "I have been crucified with Christ and I no longer live, but Christ lives in me. The life I now live in the body, I live by faith in the Son of God, who loved me and gave himself for me.",
        "Philippians 4:19": "And my God will meet all your needs according to the riches of his glory in Christ Jesus.",
        "1 John 4:19": "We love because he first loved us.",
        "Joshua 1:9": "Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.",
        "Psalm 46:10": "Be still, and know that I am God; I will be exalted among the nations, I will be exalted in the earth.",
        "Matthew 6:33": "But seek first his kingdom and his righteousness, and all these things will be given to you as well.",
        "Romans 8:38": "For I am convinced that neither death nor life, neither angels nor demons, neither the present nor the future, nor any powers,",
        "Romans 8:39": "neither height nor depth, nor anything else in all creation, will be able to separate us from the love of God that is in Christ Jesus our Lord.",
        "2 Timothy 1:7": "For the Spirit God gave us does not make us timid, but gives us power, love and self-discipline.",
        "Hebrews 11:1": "Now faith is confidence in what we hope for and assurance about what we do not see.",
        "James 1:17": "Every good and perfect gift is from above, coming down from the Father of the heavenly lights, who does not change like shifting shadows.",
        "1 Peter 5:7": "Cast all your anxiety on him because he cares for you.",
        "Exodus 9:19": "Give orders now to bring your livestock and everything you have in the field to a place of shelter, because the hail will fall on every person and animal that has not been brought in and is still out in the field, and they will die.'",
        "Genesis 1:1": "In the beginning God created the heavens and the earth.",
        "Revelation 21:4": "He will wipe every tear from their eyes. There will be no more death or mourning or crying or pain, for the old order of things has passed away."
    ]
    
    // Books of the Bible for reference validation
    private let bibleBooks: [String: Int] = [
        "Genesis": 50, "Exodus": 40, "Leviticus": 27, "Numbers": 36, "Deuteronomy": 34,
        "Joshua": 24, "Judges": 21, "Ruth": 4, "1 Samuel": 31, "2 Samuel": 24,
        "1 Kings": 22, "2 Kings": 25, "1 Chronicles": 29, "2 Chronicles": 36,
        "Ezra": 10, "Nehemiah": 13, "Esther": 10, "Job": 42, "Psalms": 150, "Psalm": 150,
        "Proverbs": 31, "Ecclesiastes": 12, "Song of Solomon": 8, "Isaiah": 66,
        "Jeremiah": 52, "Lamentations": 5, "Ezekiel": 48, "Daniel": 12,
        "Hosea": 14, "Joel": 3, "Amos": 9, "Obadiah": 1, "Jonah": 4,
        "Micah": 7, "Nahum": 3, "Habakkuk": 3, "Zephaniah": 3, "Haggai": 2,
        "Zechariah": 14, "Malachi": 4, "Matthew": 28, "Mark": 16, "Luke": 24,
        "John": 21, "Acts": 28, "Romans": 16, "1 Corinthians": 16, "2 Corinthians": 13,
        "Galatians": 6, "Ephesians": 6, "Philippians": 4, "Colossians": 4,
        "1 Thessalonians": 5, "2 Thessalonians": 3, "1 Timothy": 6, "2 Timothy": 4,
        "Titus": 3, "Philemon": 1, "Hebrews": 13, "James": 5, "1 Peter": 5,
        "2 Peter": 3, "1 John": 5, "2 John": 1, "3 John": 1, "Jude": 1,
        "Revelation": 22
    ]
    
    public init() {}
    
    public func fetch(reference: VerseReference, translation: Translation) async throws -> VerseText {
        // Small delay to simulate network request
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Check if book exists
        guard bibleBooks[reference.book] != nil else {
            throw VerseParseError.unknownBook
        }
        
        // Format reference for lookup
        let referenceKey = formatReferenceKey(reference)
        
        // Try to find verse in pre-loaded data
        if let verseText = popularVerses[referenceKey] {
            return VerseText(
                reference: reference,
                translation: translation,
                text: verseText
            )
        }
        
        // Generate fallback verse content
        let fallbackText = generateFallbackVerse(reference: reference)
        
        return VerseText(
            reference: reference,
            translation: translation,
            text: fallbackText
        )
    }
    
    /// Search for verses by content
    public func searchVerse(query: String, translation: Translation, limit: Int = 5) async throws -> [VerseText] {
        // Small delay to simulate network request
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let lowercasedQuery = query.lowercased()
        var results: [VerseText] = []
        
        // Search through popular verses
        for (key, text) in popularVerses {
            if text.lowercased().contains(lowercasedQuery) {
                if let reference = parseReferenceKey(key) {
                    let verse = VerseText(
                        reference: reference,
                        translation: translation,
                        text: text
                    )
                    results.append(verse)
                    
                    if results.count >= limit {
                        break
                    }
                }
            }
        }
        
        // If no results found, provide some default popular verses
        if results.isEmpty {
            let defaultVerses = [
                "John 3:16", "Romans 8:28", "Philippians 4:13",
                "Jeremiah 29:11", "Isaiah 41:10"
            ].prefix(limit)
            
            for key in defaultVerses {
                if let text = popularVerses[key],
                   let reference = parseReferenceKey(key) {
                    let verse = VerseText(
                        reference: reference,
                        translation: translation,
                        text: text
                    )
                    results.append(verse)
                }
            }
        }
        
        return results
    }
    
    private func formatReferenceKey(_ reference: VerseReference) -> String {
        if let endVerse = reference.endVerse {
            return "\(reference.book) \(reference.chapter):\(reference.startVerse)-\(endVerse)"
        } else {
            return "\(reference.book) \(reference.chapter):\(reference.startVerse)"
        }
    }
    
    private func parseReferenceKey(_ key: String) -> VerseReference? {
        do {
            return try VerseParser.parse(key)
        } catch {
            return nil
        }
    }
    
    private func generateFallbackVerse(reference: VerseReference) -> String {
        // Generate a meaningful fallback message
        let bookName = reference.book
        let chapter = reference.chapter
        let verse = reference.startVerse
        
        // Check if it's a valid reference structure
        if let maxChapters = bibleBooks[bookName], chapter <= maxChapters {
            return "This verse from \(bookName) \(chapter):\(verse) contains God's word for you. Please check your Bible for the complete text of this passage."
        } else {
            return "Please verify this Bible reference and try again."
        }
    }
}

// MARK: - Protocol Conformance
extension SimpleVerseAPIClient: SearchableVerseAPIClient {}
