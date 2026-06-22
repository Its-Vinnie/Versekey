import Foundation

nonisolated public enum Translation: String, CaseIterable, Codable, Sendable, Hashable {
    case kjv, asv, web, bbe, webbe, niv, nkjv, nlt, amp, msg, nasb1995, nbla, nasb2020, tpt, easy, nasv, nirv, webus, csb, esv

    public var displayCode: String {
        switch self {
        case .nasb1995:
            return "NASB95"
        case .nasb2020:
            return "NASB20"
        default:
            return rawValue.uppercased()
        }
    }
}

nonisolated public struct VerseReference: Equatable, Hashable, Codable, Sendable {
    public let book: String
    public let chapter: Int
    public let startVerse: Int
    public let endVerse: Int?
}

nonisolated public enum VerseParseError: Error, LocalizedError {
    case invalidFormat
    case unknownBook
    case invalidNumbers
    case verseNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Invalid reference format. Try 'John 3:16' or 'Romans 8:28-30'."
        case .unknownBook: return "Unknown Bible book."
        case .invalidNumbers: return "Invalid chapter or verse numbers."
        case .verseNotFound(let message): return message
        }
    }
}

nonisolated public struct VerseParser {
    private static let books: [String: String] = {
        let base = [
            // Old Testament - Full Names
            "genesis": "Genesis", "exodus": "Exodus", "leviticus": "Leviticus", "numbers": "Numbers", "deuteronomy": "Deuteronomy",
            "joshua": "Joshua", "judges": "Judges", "ruth": "Ruth",
            "1 samuel": "1 Samuel", "2 samuel": "2 Samuel",
            "1 kings": "1 Kings", "2 kings": "2 Kings",
            "1 chronicles": "1 Chronicles", "2 chronicles": "2 Chronicles",
            "ezra": "Ezra", "nehemiah": "Nehemiah", "esther": "Esther",
            "job": "Job", "psalm": "Psalms", "psalms": "Psalms",
            "proverbs": "Proverbs", "ecclesiastes": "Ecclesiastes", "song of solomon": "Song of Solomon", "song": "Song of Solomon",
            "isaiah": "Isaiah", "jeremiah": "Jeremiah", "lamentations": "Lamentations",
            "ezekiel": "Ezekiel", "daniel": "Daniel",
            "hosea": "Hosea", "joel": "Joel", "amos": "Amos", "obadiah": "Obadiah", "jonah": "Jonah",
            "micah": "Micah", "nahum": "Nahum", "habakkuk": "Habakkuk", "zephaniah": "Zephaniah",
            "haggai": "Haggai", "zechariah": "Zechariah", "malachi": "Malachi",
            
            // New Testament - Full Names
            "matthew": "Matthew", "mark": "Mark", "luke": "Luke", "john": "John",
            "acts": "Acts", "romans": "Romans",
            "1 corinthians": "1 Corinthians", "2 corinthians": "2 Corinthians",
            "galatians": "Galatians", "ephesians": "Ephesians", "philippians": "Philippians", "colossians": "Colossians",
            "1 thessalonians": "1 Thessalonians", "2 thessalonians": "2 Thessalonians",
            "1 timothy": "1 Timothy", "2 timothy": "2 Timothy",
            "titus": "Titus", "philemon": "Philemon", "hebrews": "Hebrews",
            "james": "James",
            "1 peter": "1 Peter", "2 peter": "2 Peter",
            "1 john": "1 John", "2 john": "2 John", "3 john": "3 John",
            "jude": "Jude", "revelation": "Revelation", "revelations": "Revelation",
            
            // Book Shortcuts (No Duplicates)
            "gen": "Genesis", "exo": "Exodus", "lev": "Leviticus", "num": "Numbers", "deu": "Deuteronomy",
            "jos": "Joshua", "jdg": "Judges", "rut": "Ruth", 
            "1sa": "1 Samuel", "2sa": "2 Samuel",
            "1ki": "1 Kings", "2ki": "2 Kings",
            "1ch": "1 Chronicles", "2ch": "2 Chronicles",
            "ezr": "Ezra", "neh": "Nehemiah", "est": "Esther", 
            "psa": "Psalms", "ps": "Psalms",
            "pro": "Proverbs", "ecc": "Ecclesiastes", "son": "Song of Solomon", "isa": "Isaiah",
            "jer": "Jeremiah", "lam": "Lamentations", "eze": "Ezekiel", "dan": "Daniel",
            "hos": "Hosea", "joe": "Joel", "amo": "Amos", "oba": "Obadiah", "jon": "Jonah",
            "mic": "Micah", "nah": "Nahum", "hab": "Habakkuk", "zep": "Zephaniah", "hag": "Haggai",
            "zec": "Zechariah", "mal": "Malachi", 
            "mat": "Matthew", "mar": "Mark", "luk": "Luke", "lk": "Luke", 
            "joh": "John", "jn": "John", "act": "Acts", "rom": "Romans",
            "1co": "1 Corinthians", "2co": "2 Corinthians", "gal": "Galatians", "eph": "Ephesians",
            "phi": "Philippians", "col": "Colossians", 
            "1th": "1 Thessalonians", "2th": "2 Thessalonians",
            "1ti": "1 Timothy", "2ti": "2 Timothy", "tit": "Titus", "phm": "Philemon",
            "heb": "Hebrews", "jas": "James", 
            "1pe": "1 Peter", "pet": "1 Peter", "2pe": "2 Peter",
            "1jo": "1 John", "2jo": "2 John", "3jo": "3 John", "jud": "Jude", "rev": "Revelation"
        ]
        return base
    }()

    public static func parse(_ input: String) throws -> VerseReference {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VerseParseError.invalidFormat }
        let lower = trimmed.lowercased()
        
        // Handle whole chapter references (e.g., "John 3" or "gen 1")
        if let wholeChapterRef = try? parseWholeChapter(lower) {
            return wholeChapterRef
        }
        
        // Handle verse references with complex ranges
        return try parseVerseReference(lower)
    }
    
    /// Parse complex verse patterns like "john 1:2,4-6,7" or "romans 8:28-30"
    public static func parseComplexVerses(_ input: String) throws -> [VerseReference] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        guard let digitRange = lower.range(of: #"\d"#, options: .regularExpression) else {
            throw VerseParseError.invalidFormat
        }
        
        let bookPart = lower[..<digitRange.lowerBound].trimmingCharacters(in: .whitespaces)
        let restPart = String(lower[digitRange.lowerBound...])
        
        guard let canonicalBook = books[bookPart] else { throw VerseParseError.unknownBook }
        
        let components = restPart.split(separator: ":", maxSplits: 1).map(String.init)
        guard components.count == 2, let chapter = Int(components[0]) else { 
            throw VerseParseError.invalidNumbers 
        }
        
        let versePart = components[1]
        var references: [VerseReference] = []
        
        // Split by commas for multiple verse selections
        let verseGroups = versePart.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        for group in verseGroups {
            if group.contains("-") {
                // Handle range like "4-6"
                let rangeParts = group.split(separator: "-")
                guard rangeParts.count == 2,
                      let start = Int(rangeParts[0].trimmingCharacters(in: .whitespaces)),
                      let end = Int(rangeParts[1].trimmingCharacters(in: .whitespaces)),
                      start <= end else {
                    throw VerseParseError.invalidNumbers
                }
                
                references.append(VerseReference(book: canonicalBook, chapter: chapter, startVerse: start, endVerse: end))
            } else {
                // Handle single verse like "2" or "7"
                guard let verse = Int(group) else { throw VerseParseError.invalidNumbers }
                references.append(VerseReference(book: canonicalBook, chapter: chapter, startVerse: verse, endVerse: nil))
            }
        }
        
        return references
    }
    
    private static func parseWholeChapter(_ lower: String) throws -> VerseReference? {
        // Match patterns like "john 3" or "gen 1" (no colon)
        let regex = try NSRegularExpression(pattern: #"^([a-z0-9\s]+)\s+(\d+)$"#)
        let range = NSRange(location: 0, length: lower.count)
        
        guard let match = regex.firstMatch(in: lower, range: range) else {
            return nil // Not a whole chapter reference
        }
        
        let bookRange = Range(match.range(at: 1), in: lower)!
        let chapterRange = Range(match.range(at: 2), in: lower)!
        
        let bookPart = String(lower[bookRange]).trimmingCharacters(in: .whitespaces)
        let chapterString = String(lower[chapterRange])
        
        guard let canonicalBook = books[bookPart],
              let chapter = Int(chapterString) else {
            return nil
        }
        
        // Return a reference representing the whole chapter (verse 1 to last verse)
        // For now, we'll use 1-999 as a placeholder range for whole chapters
        return VerseReference(book: canonicalBook, chapter: chapter, startVerse: 1, endVerse: 999)
    }
    
    private static func parseVerseReference(_ lower: String) throws -> VerseReference {
        guard let digitRange = lower.range(of: #"\d"#, options: .regularExpression) else {
            throw VerseParseError.invalidFormat
        }
        
        let bookPart = lower[..<digitRange.lowerBound].trimmingCharacters(in: .whitespaces)
        let restPart = lower[digitRange.lowerBound...]
        
        guard let canonicalBook = books[bookPart] else { throw VerseParseError.unknownBook }
        
        let components = restPart.split(separator: ":", maxSplits: 1).map(String.init)
        guard components.count == 2, let chapter = Int(components[0]) else { 
            throw VerseParseError.invalidNumbers 
        }
        
        let versePart = components[1]
        
        // Handle simple ranges like "28-30"
        if let dashRange = versePart.range(of: "-") {
            let startStr = versePart[..<dashRange.lowerBound]
            let endStr = versePart[dashRange.upperBound...]
            guard let start = Int(startStr), let end = Int(endStr), start <= end else { 
                throw VerseParseError.invalidNumbers 
            }
            return VerseReference(book: canonicalBook, chapter: chapter, startVerse: start, endVerse: end)
        } else {
            // Single verse
            guard let start = Int(versePart) else { throw VerseParseError.invalidNumbers }
            return VerseReference(book: canonicalBook, chapter: chapter, startVerse: start, endVerse: nil)
        }
    }
}

nonisolated public struct VerseText: Codable, Equatable, Hashable, Sendable {
    public let reference: VerseReference
    public let translation: Translation
    public let text: String
}

nonisolated public protocol VerseAPIClient {
    func fetch(reference: VerseReference, translation: Translation) async throws -> VerseText
}

public actor VerseCache {
    private var memory: [VerseKey: VerseText] = [:]
    private var order: [VerseKey] = []
    private let memoryLimit = 20
    private let diskURL: URL

    public init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskURL = dir.appendingPathComponent("VerseCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskURL, withIntermediateDirectories: true)
    }

    private func key(for reference: VerseReference, translation: Translation) -> VerseKey {
        VerseKey(book: reference.book, chapter: reference.chapter, start: reference.startVerse, end: reference.endVerse, tr: translation.rawValue)
    }

    public func get(reference: VerseReference, translation: Translation) async -> VerseText? {
        let k = key(for: reference, translation: translation)
        if let v = memory[k] { touch(k); return v }
        if let v = try? readDisk(k) { setMemory(v, for: k); return v }
        return nil
    }

    public func set(_ verse: VerseText) async {
        let k = key(for: verse.reference, translation: verse.translation)
        setMemory(verse, for: k)
        try? writeDisk(verse, for: k)
    }

    private func setMemory(_ v: VerseText, for k: VerseKey) {
        memory[k] = v
        touch(k)
        if order.count > memoryLimit, let drop = order.first { memory.removeValue(forKey: drop); order.removeFirst() }
    }

    private func touch(_ k: VerseKey) { order.removeAll { $0 == k }; order.append(k) }
    private func url(for k: VerseKey) -> URL { diskURL.appendingPathComponent(k.filename) }

    private func readDisk(_ k: VerseKey) throws -> VerseText? {
        let url = url(for: k)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(DiskEntry.self, from: data)
        if Date().timeIntervalSince1970 - decoded.timestamp > 24 * 60 * 60 { try? FileManager.default.removeItem(at: url); return nil }
        return decoded.payload
    }

    private func writeDisk(_ v: VerseText, for k: VerseKey) throws {
        let entry = DiskEntry(timestamp: Date().timeIntervalSince1970, payload: v)
        let data = try JSONEncoder().encode(entry)
        try data.write(to: url(for: k), options: .atomic)
    }

    private struct DiskEntry: Codable { let timestamp: TimeInterval; let payload: VerseText }
}

nonisolated private struct VerseKey: Hashable, Codable {
    let book: String
    let chapter: Int
    let start: Int
    let end: Int?
    let tr: String
    var filename: String {
        let endStr = end.map(String.init) ?? "_"
        return "\(book)-\(chapter)-\(start)-\(endStr)-\(tr)".replacingOccurrences(of: " ", with: "_") + ".json"
    }
}

public actor VerseService {
    private let api: VerseAPIClient
    private let cache: VerseCache

    public init(api: VerseAPIClient, cache: VerseCache = VerseCache()) {
        self.api = api
        self.cache = cache
    }

    public func getVerse(reference: VerseReference, translation: Translation) async throws -> VerseText {
        if let cached = await cache.get(reference: reference, translation: translation) { return cached }
        let fetched = try await api.fetch(reference: reference, translation: translation)
        await cache.set(fetched)
        return fetched
    }
}

nonisolated public struct StubAPIClient: VerseAPIClient {
    public init() {}
    public func fetch(reference: VerseReference, translation: Translation) async throws -> VerseText {
        try await Task.sleep(nanoseconds: 250_000_000)
        let ref: String
        if let end = reference.endVerse { ref = "\(reference.book) \(reference.chapter):\(reference.startVerse)-\(end)" }
        else { ref = "\(reference.book) \(reference.chapter):\(reference.startVerse)" }
        let text = "[\(translation.rawValue.uppercased())] Sample text for \(ref). Replace with real API response."
        return VerseText(reference: reference, translation: translation, text: text)
    }
}

nonisolated public enum InsertFormat: String, CaseIterable, Hashable {
    case textOnly
    case textAndReference
    case referenceOnly
}

nonisolated public struct InsertFormatter {
    public init() {}

    private func header(for reference: VerseReference, translation: Translation) -> String {
        let ref: String
        if let end = reference.endVerse {
            ref = "\(reference.book) \(reference.chapter):\(reference.startVerse)-\(end)"
        } else {
            ref = "\(reference.book) \(reference.chapter):\(reference.startVerse)"
        }
        return "\(ref) (\(translation.displayCode)) 📖"
    }

    private func stripLeadingVerseMarkers(_ text: String) -> String {
        let patterns = [
            "^\\s*\\[?\\(?\\s*\\d+\\s*\\]?\\)?\\s*", // [16] or (16) or 16
        ]
        var cleaned = text
        for p in patterns {
            cleaned = cleaned.replacingOccurrences(of: p, with: "", options: .regularExpression)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func flattenedInline(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"[ \t]*[\r\n]+[ \t]*"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func looksLikeSectionTitle(_ text: String) -> Bool {
        let words = text.split(whereSeparator: \.isWhitespace)
        return !text.isEmpty && text.count <= 90 && words.count <= 12 && !text.hasSuffix(".")
    }

    private func formattedSingleVerseBody(_ text: String, verseNumber: Int) -> String {
        let cleaned = stripLeadingVerseMarkers(text)
        let markerPattern = "\\[\\s*\(verseNumber)\\s*\\]"
        guard let regex = try? NSRegularExpression(pattern: markerPattern),
              let match = regex.firstMatch(in: cleaned, range: NSRange(location: 0, length: (cleaned as NSString).length)),
              match.range.location > 0 else {
            return "\(verseNumber) \(flattenedInline(cleaned))"
        }

        let ns = cleaned as NSString
        let title = flattenedInline(ns.substring(with: NSRange(location: 0, length: match.range.location)))
        let restStart = match.range.location + match.range.length
        let restLength = max(0, ns.length - restStart)
        let body = flattenedInline(ns.substring(with: NSRange(location: restStart, length: restLength)))

        guard looksLikeSectionTitle(title), !body.isEmpty else {
            return "\(verseNumber) \(flattenedInline(cleaned))"
        }

        return "\(title)\n\n\(verseNumber) \(body)"
    }

    private func headerBodySeparator(for formattedBody: String, firstVerseNumber: Int) -> String {
        formattedBody.hasPrefix("\(firstVerseNumber) ") ? "\n\n" : "\n"
    }

    private func splitByEmbeddedVerseMarkers(_ text: String) -> [(num: Int, body: String)] {
        let pattern = #"\[\s*(\d+)\s*\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: text, range: fullRange)
        guard !matches.isEmpty else { return [] }

        var parts: [(Int, String)] = []
        for (idx, m) in matches.enumerated() {
            guard m.numberOfRanges >= 2 else { continue }
            let numRange = m.range(at: 1)
            let numStr = ns.substring(with: numRange)
            guard let n = Int(numStr) else { continue }

            let startLoc = m.range.location + m.range.length
            let endLoc: Int
            if idx + 1 < matches.count {
                endLoc = matches[idx + 1].range.location
            } else {
                endLoc = ns.length
            }
            let len = max(0, endLoc - startLoc)
            let rawSlice = len > 0 ? ns.substring(with: NSRange(location: startLoc, length: len)) : ""
            parts.append((n, flattenedInline(rawSlice)))
        }
        return parts
    }

    public func formatPremiumSingle(_ verse: VerseText) -> String {
        let headerLine = header(for: verse.reference, translation: verse.translation)

        if let end = verse.reference.endVerse, end >= verse.reference.startVerse {
            let segments = splitByEmbeddedVerseMarkers(verse.text)
            if !segments.isEmpty {
                let lines = segments.map { seg in
                    "\(seg.num) \(seg.body)"
                }
                return headerLine + "\n\n" + lines.joined(separator: "\n\n")
            }
        }

        let n = verse.reference.startVerse
        let body = formattedSingleVerseBody(verse.text, verseNumber: n)
        return headerLine + headerBodySeparator(for: body, firstVerseNumber: n) + body
    }

    public func formatPremiumMultiple(headerRef: String, translation: Translation, verses: [VerseText]) -> String {
        let headerLine = "\(headerRef) (\(translation.displayCode)) 📖"
        let sortedVerses = verses.sorted { $0.reference.startVerse < $1.reference.startVerse }
        let lines = sortedVerses
            .map { v in
                let n = v.reference.startVerse
                return formattedSingleVerseBody(v.text, verseNumber: n)
            }
        let firstVerseNumber = sortedVerses.first?.reference.startVerse ?? 1
        let body = lines.joined(separator: "\n\n")
        return headerLine + headerBodySeparator(for: body, firstVerseNumber: firstVerseNumber) + body
    }

    public func format(_ verse: VerseText, as format: InsertFormat) -> String {
        let ref: String
        if let end = verse.reference.endVerse {
            ref = "\(verse.reference.book) \(verse.reference.chapter):\(verse.reference.startVerse)-\(end)"
        } else {
            ref = "\(verse.reference.book) \(verse.reference.chapter):\(verse.reference.startVerse)"
        }
        switch format {
        case .textOnly:
            let flattened = verse.text
                .replacingOccurrences(of: #"[ \t]*[\r\n]+[ \t]*"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return flattened
        case .textAndReference:
            let flattened = verse.text
                .replacingOccurrences(of: #"[ \t]*[\r\n]+[ \t]*"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(flattened) — \(ref) [\(verse.translation.displayCode)]"
        case .referenceOnly:
            return "\(ref) [\(verse.translation.displayCode)]"
        }
    }
}
