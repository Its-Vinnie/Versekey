//
//  BrowseView.swift
//  VerseFinderApp
//
//  Created by Maphari Vincent on 2026/03/02.
//

import SwiftUI
import UIKit

public struct BrowseView: View {
    public let selectedBook: String?
    public let selectedChapter: Int?
    public let verseCount: Int
    public let translation: Translation
    public let onSelectBook: (BibleBook) -> Void
    public let onSelectChapter: (Int) -> Void
    public let onSelectVerse: (Int) -> Void
    public let onBackToBooks: () -> Void
    public let onBackToChapters: () -> Void

    public let isMultiSelectEnabled: Bool
    public let selectedVerses: Set<Int>
    public let onToggleMultiSelect: () -> Void
    public let onFetchSelected: () -> Void
    public let onFetchWholeChapter: () -> Void
    public let isWholeChapterMode: Bool
    public let onToggleWholeChapterMode: () -> Void
    public let showsSelectionHeader: Bool

    public init(selectedBook: String?, selectedChapter: Int?, verseCount: Int, translation: Translation, onSelectBook: @escaping (BibleBook) -> Void, onSelectChapter: @escaping (Int) -> Void, onSelectVerse: @escaping (Int) -> Void, onBackToBooks: @escaping () -> Void, onBackToChapters: @escaping () -> Void, isMultiSelectEnabled: Bool = false, selectedVerses: Set<Int> = [], onToggleMultiSelect: @escaping () -> Void = {}, onFetchSelected: @escaping () -> Void = {}, onFetchWholeChapter: @escaping () -> Void = {}, isWholeChapterMode: Bool = false, onToggleWholeChapterMode: @escaping () -> Void = {}, showsSelectionHeader: Bool = true) {
        self.selectedBook = selectedBook
        self.selectedChapter = selectedChapter
        self.verseCount = verseCount
        self.translation = translation
        self.onSelectBook = onSelectBook
        self.onSelectChapter = onSelectChapter
        self.onSelectVerse = onSelectVerse
        self.onBackToBooks = onBackToBooks
        self.onBackToChapters = onBackToChapters
        self.isMultiSelectEnabled = isMultiSelectEnabled
        self.selectedVerses = selectedVerses
        self.onToggleMultiSelect = onToggleMultiSelect
        self.onFetchSelected = onFetchSelected
        self.onFetchWholeChapter = onFetchWholeChapter
        self.isWholeChapterMode = isWholeChapterMode
        self.onToggleWholeChapterMode = onToggleWholeChapterMode
        self.showsSelectionHeader = showsSelectionHeader
    }

    private var filteredOldTestament: [BibleBook] {
        filterBooks(BibleCatalog.oldTestament)
    }
    private var filteredNewTestament: [BibleBook] {
        filterBooks(BibleCatalog.newTestament)
    }
    private func filterBooks(_ books: [BibleBook]) -> [BibleBook] {
        guard translation == .tpt else { return books }
        let allowed: Set<String> = [
            // OT subset for TPT (exclude Genesis and other unavailable books)
            "Joshua","Judges","Ruth","Psalms","Proverbs","Song of Solomon","Song of Songs","Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos","Obadiah","Jonah","Micah","Nahum","Habakkuk","Zephaniah","Haggai","Zechariah","Malachi",
            // NT
            "Matthew","Mark","Luke","John","Acts","Romans","1 Corinthians","2 Corinthians","Galatians","Ephesians","Philippians","Colossians","1 Thessalonians","2 Thessalonians","1 Timothy","2 Timothy","Titus","Philemon","Hebrews","James","1 Peter","2 Peter","1 John","2 John","3 John","Jude","Revelation"
        ]
        return books.filter { allowed.contains($0.name) }
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Removed "Browse" label for a cleaner look; sections will anchor the layout
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if selectedBook == nil {
                        SectionHeader("Old Testament")
                        BookGrid(books: filteredOldTestament) { book in onSelectBook(book) }
                        SectionHeader("New Testament")
                        BookGrid(books: filteredNewTestament) { book in onSelectBook(book) }
                    } else if let bookName = selectedBook, selectedChapter == nil {
                        if showsSelectionHeader {
                            SectionHeader(bookName)
                        }
                        HStack {
                            Spacer()
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onToggleWholeChapterMode()
                            }) {
                                Text("Select Whole Chapter")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(isWholeChapterMode ? .white : .primary)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(
                                        Capsule()
                                            .fill(isWholeChapterMode ? Color.accentColor : Color(UIColor.secondarySystemGroupedBackground))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(isWholeChapterMode ? Color.accentColor.opacity(0.6) : Color(UIColor.separator).opacity(0.4), lineWidth: 0.8)
                                    )
                                    .shadow(color: isWholeChapterMode ? Color.accentColor.opacity(0.25) : Color.clear, radius: isWholeChapterMode ? 6 : 0, x: 0, y: 2)
                                    .animation(.easeInOut(duration: 0.2), value: isWholeChapterMode)
                            }
                            .buttonStyle(.plain)
                        }
                        let chapters = ((filteredOldTestament + filteredNewTestament).first { $0.name == bookName }?.chapters) ?? 1
                        ChapterGrid(chapters: chapters) { ch in onSelectChapter(ch) }
                        Button(action: { onBackToBooks() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                                Text("Back to Books").font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    } else if let bookName = selectedBook, let ch = selectedChapter {
                        if showsSelectionHeader {
                            SectionHeader("\(bookName) \(ch)")
                        }
                        HStack(spacing: 8) {
                            Spacer()
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onToggleMultiSelect()
                            }) {
                                HStack(spacing: 6) {
                                    Text("Multi-select")
                                        .font(.system(size: 13, weight: .semibold))
                                    if isMultiSelectEnabled && !selectedVerses.isEmpty {
                                        Text("\(selectedVerses.count)")
                                            .font(.system(size: 11, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.white.opacity(0.25)))
                                    }
                                }
                                .foregroundColor(isMultiSelectEnabled ? .white : .primary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule()
                                        .fill(isMultiSelectEnabled ? Color.accentColor : Color(UIColor.secondarySystemGroupedBackground))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(isMultiSelectEnabled ? Color.accentColor.opacity(0.6) : Color(UIColor.separator).opacity(0.4), lineWidth: 0.8)
                                )
                                .shadow(color: isMultiSelectEnabled ? Color.accentColor.opacity(0.25) : Color.clear, radius: isMultiSelectEnabled ? 6 : 0, x: 0, y: 2)
                                .animation(.easeInOut(duration: 0.2), value: isMultiSelectEnabled)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                if isMultiSelectEnabled && !selectedVerses.isEmpty {
                                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                }
                                onFetchSelected()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 12, weight: .semibold))
                                    Text("Fetch Selected").font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.primary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule()
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color(UIColor.separator).opacity(0.4), lineWidth: 0.8)
                                )
                                .shadow(color: (isMultiSelectEnabled && !selectedVerses.isEmpty) ? Color.accentColor.opacity(0.18) : Color.clear, radius: (isMultiSelectEnabled && !selectedVerses.isEmpty) ? 5 : 0, x: 0, y: 2)
                                .animation(.easeInOut(duration: 0.2), value: selectedVerses.count)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isMultiSelectEnabled || selectedVerses.isEmpty)
                        }
                        VerseGrid(verses: verseCount, selectedVerses: selectedVerses, isMultiSelectEnabled: isMultiSelectEnabled) { v in onSelectVerse(v) }
                        HStack(spacing: 12) {
                            Button(action: { onBackToChapters() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                                    Text("Chapters").font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            Button(action: { onBackToBooks() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "house").font(.system(size: 14, weight: .semibold))
                                    Text("Books").font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(8)
        .onChange(of: translation) { _, _ in
            let allAllowed = Set((filterBooks(BibleCatalog.oldTestament) + filterBooks(BibleCatalog.newTestament)).map { $0.name })
            if let sel = selectedBook, !allAllowed.contains(sel) {
                onBackToBooks()
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title).font(.subheadline.bold())
    }
}

private struct BrowseTileStyle: ViewModifier {
    let cornerRadius: CGFloat
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var fillColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.accentColor.opacity(0.24) : Color.accentColor.opacity(0.16)
        }
        return colorScheme == .dark
            ? Color(UIColor.secondarySystemGroupedBackground)
            : Color(UIColor.systemBackground)
    }

    private var strokeColor: Color {
        if isSelected {
            return Color.accentColor
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.08)
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(strokeColor, lineWidth: isSelected ? 1.5 : 0.8)
                    )
                    .shadow(
                        color: colorScheme == .dark ? Color.black.opacity(0.16) : Color.black.opacity(0.06),
                        radius: colorScheme == .dark ? 1 : 5,
                        x: 0,
                        y: colorScheme == .dark ? 1 : 2
                    )
            )
    }
}

private extension View {
    func browseTile(cornerRadius: CGFloat = 10, isSelected: Bool = false) -> some View {
        modifier(BrowseTileStyle(cornerRadius: cornerRadius, isSelected: isSelected))
    }
}

private struct BookGrid: View {
    let books: [BibleBook]
    let onTap: (BibleBook) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(books) { book in
                Button(action: { onTap(book) }) {
                    Text(book.name)
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity)
                        .browseTile()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ChapterGrid: View {
    let chapters: Int
    let onTap: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(1...chapters, id: \.self) { ch in
                Button(action: { onTap(ch) }) {
                    Text("\(ch)")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity)
                        .browseTile()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct VerseGridLoadingView: View {
    @State private var beamOffset: CGFloat = -240
    @State private var pulse: Bool = false
    @State private var haloPulse: Bool = false

    var body: some View {
        ZStack {
            // Card container with subtle inner glow
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
                        .blur(radius: 1)
                        .opacity(0.9)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)

            // Dynamic halo around the card edges (Siri-like aura)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.0),
                            Color.accentColor.opacity(0.55),
                            Color.blue.opacity(0.35),
                            Color.purple.opacity(0.35),
                            Color.accentColor.opacity(0.0)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: haloPulse ? 7 : 5
                )
                .blur(radius: haloPulse ? 12 : 8)
                .scaleEffect(haloPulse ? 1.02 : 0.99)
                .opacity(0.9)

            // Animated sweeping beam
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(0.05),
                    Color.accentColor.opacity(0.35),
                    Color.accentColor.opacity(0.05)
                ]),
                startPoint: .leading, endPoint: .trailing
            )
            .mask(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .opacity(0.9)
                    .offset(x: beamOffset)
            )
            .blur(radius: 16)

            // Placeholder content blocks to suggest verse buttons
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(0..<8) { _ in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.22))
                            .frame(height: 24)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(0..<8) { _ in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.22))
                            .frame(height: 24)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(0..<8) { _ in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.22))
                            .frame(height: 24)
                    }
                }
            }
            .padding(14)
        }
        .frame(height: 120)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                beamOffset = 240
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                haloPulse = true
            }
        }
    }
}

private struct VerseGrid: View {
    let verses: Int
    let selectedVerses: Set<Int>
    let isMultiSelectEnabled: Bool
    let onTap: (Int) -> Void

    var body: some View {
        Group {
            if verses > 0 {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                    ForEach(1...verses, id: \.self) { v in
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onTap(v)
                        }) {
                            Text("\(v)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity)
                                .browseTile(cornerRadius: 8, isSelected: selectedVerses.contains(v))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if verses == 0 {
                VerseGridLoadingView()
            } else {
                Text("Could not load verses for this chapter.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
            }
        }
    }
}
