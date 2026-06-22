//
//  BibleBook.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/02.
//


import Foundation

public struct BibleBook: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let chapters: Int
    public let testament: Testament
}

public enum Testament: String, CaseIterable { case old, new }

public struct BibleCatalog {
    public static let books: [BibleBook] = {
        var list: [BibleBook] = []
        func add(_ name: String, chapters: Int, testament: Testament) { list.append(BibleBook(id: name, name: name, chapters: chapters, testament: testament)) }
        // Minimal chapter counts; can be refined later
        add("Genesis", chapters: 50, testament: .old); add("Exodus", chapters: 40, testament: .old); add("Leviticus", chapters: 27, testament: .old); add("Numbers", chapters: 36, testament: .old); add("Deuteronomy", chapters: 34, testament: .old)
        add("Joshua", chapters: 24, testament: .old); add("Judges", chapters: 21, testament: .old); add("Ruth", chapters: 4, testament: .old)
        add("1 Samuel", chapters: 31, testament: .old); add("2 Samuel", chapters: 24, testament: .old)
        add("1 Kings", chapters: 22, testament: .old); add("2 Kings", chapters: 25, testament: .old)
        add("1 Chronicles", chapters: 29, testament: .old); add("2 Chronicles", chapters: 36, testament: .old)
        add("Ezra", chapters: 10, testament: .old); add("Nehemiah", chapters: 13, testament: .old); add("Esther", chapters: 10, testament: .old)
        add("Job", chapters: 42, testament: .old); add("Psalms", chapters: 150, testament: .old); add("Proverbs", chapters: 31, testament: .old); add("Ecclesiastes", chapters: 12, testament: .old); add("Song of Solomon", chapters: 8, testament: .old)
        add("Isaiah", chapters: 66, testament: .old); add("Jeremiah", chapters: 52, testament: .old); add("Lamentations", chapters: 5, testament: .old)
        add("Ezekiel", chapters: 48, testament: .old); add("Daniel", chapters: 12, testament: .old)
        add("Hosea", chapters: 14, testament: .old); add("Joel", chapters: 3, testament: .old); add("Amos", chapters: 9, testament: .old); add("Obadiah", chapters: 1, testament: .old); add("Jonah", chapters: 4, testament: .old); add("Micah", chapters: 7, testament: .old); add("Nahum", chapters: 3, testament: .old); add("Habakkuk", chapters: 3, testament: .old); add("Zephaniah", chapters: 3, testament: .old); add("Haggai", chapters: 2, testament: .old); add("Zechariah", chapters: 14, testament: .old); add("Malachi", chapters: 4, testament: .old)
        add("Matthew", chapters: 28, testament: .new); add("Mark", chapters: 16, testament: .new); add("Luke", chapters: 24, testament: .new); add("John", chapters: 21, testament: .new)
        add("Acts", chapters: 28, testament: .new)
        add("Romans", chapters: 16, testament: .new)
        add("1 Corinthians", chapters: 16, testament: .new); add("2 Corinthians", chapters: 13, testament: .new)
        add("Galatians", chapters: 6, testament: .new); add("Ephesians", chapters: 6, testament: .new); add("Philippians", chapters: 4, testament: .new); add("Colossians", chapters: 4, testament: .new)
        add("1 Thessalonians", chapters: 5, testament: .new); add("2 Thessalonians", chapters: 3, testament: .new)
        add("1 Timothy", chapters: 6, testament: .new); add("2 Timothy", chapters: 4, testament: .new)
        add("Titus", chapters: 3, testament: .new); add("Philemon", chapters: 1, testament: .new)
        add("Hebrews", chapters: 13, testament: .new)
        add("James", chapters: 5, testament: .new)
        add("1 Peter", chapters: 5, testament: .new); add("2 Peter", chapters: 3, testament: .new)
        add("1 John", chapters: 5, testament: .new); add("2 John", chapters: 1, testament: .new); add("3 John", chapters: 1, testament: .new)
        add("Jude", chapters: 1, testament: .new)
        add("Revelation", chapters: 22, testament: .new)
        return list
    }()

    public static let oldTestament: [BibleBook] = books.filter { $0.testament == .old }
    public static let newTestament: [BibleBook] = books.filter { $0.testament == .new }
}

