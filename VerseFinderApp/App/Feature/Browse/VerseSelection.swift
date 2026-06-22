// VerseSelection.swift
// Represents the user's verse selection in a normalized model for Search Mode.

import Foundation

public enum VerseSelection: Equatable {
    case single(book: String, chapter: Int, verse: Int)
    case range(book: String, chapter: Int, start: Int, end: Int)
    case list(book: String, chapter: Int, verses: [Int])
    case chapter(book: String, chapter: Int)
}

public extension VerseSelection {
    // Build selections from a free-form query using existing VerseParser behavior.
    // This function favors a single normalized representation:
    // - A whole chapter becomes `.chapter` (detected via endVerse == 999 convention)
    // - A simple range becomes `.range`
    // - A simple single verse becomes `.single`
    // - A comma-separated list in the same chapter becomes `.list`; otherwise returns multiple selections
    static func fromQuery(_ input: String) -> [VerseSelection] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // If it looks like a list (comma/semicolon), try complex parse first
        if trimmed.contains(",") || trimmed.contains(";") {
            if let refs = try? VerseParser.parseComplexVerses(trimmed) {
                // If all references share the same book+chapter and are single verses, collapse to a list
                if let first = refs.first {
                    let sameBookChapter = refs.allSatisfy { $0.book == first.book && $0.chapter == first.chapter }
                    let singles = refs.compactMap { ref -> Int? in
                        if ref.endVerse == nil { return ref.startVerse } else { return nil }
                    }
                    if sameBookChapter && singles.count == refs.count {
                        return [.list(book: first.book, chapter: first.chapter, verses: singles)]
                    }
                }
                // Otherwise, map each reference to its best-fit selection
                return refs.map { ref in
                    if let end = ref.endVerse {
                        // Detect whole chapter convention (1...999) as chapter
                        if ref.startVerse == 1 && end == 999 { return .chapter(book: ref.book, chapter: ref.chapter) }
                        return .range(book: ref.book, chapter: ref.chapter, start: ref.startVerse, end: end)
                    } else {
                        return .single(book: ref.book, chapter: ref.chapter, verse: ref.startVerse)
                    }
                }
            }
        }

        // Fallback to simple parse
        if let ref = try? VerseParser.parse(trimmed) {
            if let end = ref.endVerse {
                if ref.startVerse == 1 && end == 999 {
                    return [.chapter(book: ref.book, chapter: ref.chapter)]
                }
                return [.range(book: ref.book, chapter: ref.chapter, start: ref.startVerse, end: end)]
            } else {
                return [.single(book: ref.book, chapter: ref.chapter, verse: ref.startVerse)]
            }
        }

        return []
    }
}
