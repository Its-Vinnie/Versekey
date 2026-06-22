import Foundation
import Combine
import UIKit
import Speech

@MainActor
public final class KeyboardViewModel: ObservableObject {
    public enum KeyboardMode: String, CaseIterable {
        case search = "Search"
        case browse = "Browse"
    }

    public enum UIState: Equatable {
        case idle
        case typingGlow
        case loadingSearch
        case loadingTranslationSwitch
        case showingResult
        case listening
        case processingVoice
        case error(String)
    }

    public enum InputFocus { case host, search }
    public enum PresentationState { case typing, showingSearchResult, showingBrowseResult, listening, loading }

    public struct VerseResult {
        public let referenceLabel: String
        public let previewText: String
        public let fullText: String
        public let translation: Translation
    }

    private let translationsWithoutRangeOrChapter: Set<Translation> = [.tpt, .easy, .nirv, .nasb2020, .nasv]

    public enum PreviewLength: Int, CaseIterable {
        case short = 120
        case medium = 180
        case long = 260
    }

    @Published public var mode: KeyboardMode = .search
    @Published public var query: String = ""
    @Published public var selectedTranslation: Translation = .niv
    @Published public var insertFormat: InsertFormat = .textAndReference
    @Published public var uiState: UIState = .idle
    @Published public var errorMessage: String? = nil
    @Published public var partialTranscript: String? = nil

    @Published public var searchResult: VerseResult? = nil
    @Published public var browseResult: VerseResult? = nil

    @Published public var previewLength: PreviewLength = .medium
    @Published public var availableTranslations: [Translation] = []
    @Published public var hapticsEnabled: Bool = true

    // Browse navigation state
    @Published public var selectedBook: String? = nil
    @Published public var selectedChapter: Int? = nil
    @Published public var selectedVerse: Int? = nil
    @Published public var currentChapterVerseCount: Int = 0

    @Published public var isMultiSelectEnabled: Bool = false
    @Published public var selectedVersesSet: Set<Int> = []
    @Published public var isWholeChapterMode: Bool = false

    @Published public var inputFocus: InputFocus = .host
    @Published public var presentation: PresentationState = .typing

    internal var fetchTask: Task<Void, Never>? = nil

    private var client: CombinedAPIClient { CombinedAPIClient() }
    private let formatter = InsertFormatter()
    private let inserter: InsertPipeline
    private lazy var speechService = SpeechRecognizerService()
    private let settings: SettingsStore
    private let historyStore = HistoryStore()

    public init(inserter: InsertPipeline, settings: SettingsStore) {
        self.inserter = inserter
        self.settings = settings

        if let t = Translation(rawValue: settings.defaultTranslation.lowercased()) {
            self.selectedTranslation = t
        }

        let plValue = settings.previewLength
        if plValue >= 240 {
            self.previewLength = .long
        } else if plValue >= 160 {
            self.previewLength = .medium
        } else {
            self.previewLength = .short
        }

        self.insertFormat = InsertFormat(rawValue: settings.insertFormat.rawValue) ?? .textAndReference
        self.availableTranslations = Self.mapTranslations(settings.translationsShown)
        self.hapticsEnabled = settings.hapticsEnabled
    }

    private static func mapTranslations(_ codes: [String]) -> [Translation] {
        let mapped = codes.compactMap { Translation(rawValue: $0.lowercased()) }
        return mapped.isEmpty ? [.esv, .kjv, .nkjv, .niv, .nlt, .amp, .msg, .tpt, .asv, .csb, .easy, .nasb1995, .nasb2020, .web, .bbe, .webbe, .nirv, .webus] : mapped
    }

    // MARK: - Reference label formatter

    private func makeReferenceLabel(from refCore: String) -> String {
        "\(refCore) (\(self.selectedTranslation.displayCode)) 📖"
    }

    // MARK: - Preview helpers (nonisolated so they’re callable off-main)

    nonisolated private static func flattenWhitespace(_ s: String) -> String {
        s.replacingOccurrences(of: #"[ \t]*[\r\n]+[ \t]*"#, with: " ", options: .regularExpression)
         .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func extractBody(from formatted: String) -> String {
        let parts = formatted.components(separatedBy: "\n\n")
        let bodyParts = parts.dropFirst()
        let bodyJoined = bodyParts.joined(separator: " ")
        return flattenWhitespace(bodyJoined)
    }

    nonisolated private static func truncate(_ text: String, to limit: Int) -> String {
        if text.count <= limit { return text }
        var truncated = String(text.prefix(limit))
        if let lastSpace = truncated.lastIndex(of: " ") {
            truncated = String(truncated[..<lastSpace])
        }
        return truncated + "…"
    }

    nonisolated private static func previewBody(from formattedFull: String, limit: Int) -> String {
        let bodyOnly = extractBody(from: formattedFull)
        return truncate(bodyOnly, to: limit)
    }

    private func effectivePreviewLimit(for length: PreviewLength) -> Int {
        let settingLimit: Int
        switch length {
        case .short:  settingLimit = 120
        case .medium: settingLimit = 180
        case .long:   settingLimit = 260
        }
        return min(settingLimit, 240)
    }

    private func normalizeVoice(_ raw: String) -> String {
        var s = raw.lowercased()
        s = s.replacingOccurrences(of: "first john", with: "1 john")
        s = s.replacingOccurrences(of: "second john", with: "2 john")
        s = s.replacingOccurrences(of: "third john", with: "3 john")
        s = s.replacingOccurrences(of: "one john", with: "1 john")
        s = s.replacingOccurrences(of: "two john", with: "2 john")
        s = s.replacingOccurrences(of: "three john", with: "3 john")
        s = s.replacingOccurrences(of: " through ", with: "-")
        s = s.replacingOccurrences(of: " to ", with: "-")
        s = s.replacingOccurrences(of: " and ", with: ",")
        s = s.replacingOccurrences(of: " comma ", with: ",")
        s = s.replacingOccurrences(of: " chapter ", with: " ")
        s = s.replacingOccurrences(of: " verses ", with: ":")
        s = s.replacingOccurrences(of: " verse ", with: ":")
        let fillers = ["please ", "show me ", "give me ", "from "]
        for f in fillers { s = s.replacingOccurrences(of: f, with: "") }
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func userFacingErrorMessage(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .networkError(let underlying):
                return userFacingErrorMessage(underlying)
            default:
                return apiError.errorDescription ?? "Could not load the verse. Please try again."
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "Could not reach the Bible service. Check your connection and enable Allow Full Access for VerseKey."
            case .notConnectedToInternet, .networkConnectionLost, .internationalRoamingOff, .dataNotAllowed:
                return "You're offline. Check your connection and try again."
            case .timedOut:
                return "The Bible service took too long to respond. Please try again."
            default:
                return "Network error. Check your connection and try again."
            }
        }

        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }

        return "Could not load the verse. Please try again."
    }

    // MARK: - Core fetch pipeline (network off the main actor)

    private func runFetchPipeline(reference: VerseReference, loadingState: UIState, isBrowse: Bool) {
        fetchTask?.cancel()
        uiState = loadingState
        presentation = .loading

        // Snapshot values needed off-main
        let client = self.client
        let formatter = self.formatter
        let translation = self.selectedTranslation
        let previewCap = self.effectivePreviewLimit(for: self.previewLength)

        fetchTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let verse = try await client.fetch(reference: reference, translation: translation)
                let full = formatter.formatPremiumSingle(verse)
                let preview = KeyboardViewModel.previewBody(from: full, limit: previewCap)

                if Task.isCancelled { return }
                let strongSelf = self
                await MainActor.run {
                    guard let strongSelf else { return }
                    let refCore: String = {
                        if let end = verse.reference.endVerse {
                            return "\(verse.reference.book) \(verse.reference.chapter):\(verse.reference.startVerse)-\(end)"
                        } else {
                            return "\(verse.reference.book) \(verse.reference.chapter):\(verse.reference.startVerse)"
                        }
                    }()
                    let built = VerseResult(
                        referenceLabel: strongSelf.makeReferenceLabel(from: refCore),
                        previewText: preview,
                        fullText: full,
                        translation: translation
                    )
                    if isBrowse {
                        strongSelf.browseResult = built
                        strongSelf.searchResult = nil
                        strongSelf.presentation = .showingBrowseResult
                    } else {
                        strongSelf.searchResult = built
                        strongSelf.browseResult = nil
                        strongSelf.presentation = .showingSearchResult
                    }
                    strongSelf.uiState = .showingResult
                    strongSelf.errorMessage = nil
                }
            } catch is CancellationError {
                // ignore
            } catch {
                let strongSelf = self
                await MainActor.run {
                    guard let strongSelf else { return }
                    strongSelf.errorMessage = Self.userFacingErrorMessage(error)
                    strongSelf.uiState = .error(strongSelf.errorMessage ?? "Unknown error")
                }
            }
        }
    }

    // Parallel multi-verse fetch (off-main)
    private func fetchMultipleVerses(book: String, chapter: Int, verses: [Int], translation: Translation) async throws -> [VerseText] {
        let client = self.client
        return try await withThrowingTaskGroup(of: (Int, VerseText).self) { group in
            for v in verses {
                group.addTask {
                    let ref = VerseReference(book: book, chapter: chapter, startVerse: v, endVerse: nil)
                    let verse = try await client.fetch(reference: ref, translation: translation)
                    return (v, verse)
                }
            }
            var collected: [(Int, VerseText)] = []
            for try await pair in group {
                collected.append(pair)
            }
            // Ensure order by verse number
            return collected.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }

    private func buildCombinedResult(book: String, chapter: Int, verses: [Int], fetched: [VerseText]) -> VerseResult {
        func refString(book: String, chapter: Int, verses: [Int]) -> String {
            guard let _ = verses.first, let _ = verses.last else { return "\(book) \(chapter)" }
            let sorted = verses.sorted()
            let isContiguous = sorted.enumerated().allSatisfy { idx, v in idx == 0 || v == sorted[idx-1] + 1 }
            if isContiguous && sorted.count > 1 {
                return "\(book) \(chapter):\(sorted.first!)-\(sorted.last!)"
            } else {
                return "\(book) \(chapter):\(sorted.map(String.init).joined(separator: ","))"
            }
        }

        let refCore = refString(book: book, chapter: chapter, verses: verses)
        let full = formatter.formatPremiumMultiple(headerRef: refCore, translation: selectedTranslation, verses: fetched)
        let preview = KeyboardViewModel.previewBody(from: full, limit: effectivePreviewLimit(for: previewLength))
        return VerseResult(
            referenceLabel: makeReferenceLabel(from: refCore),
            previewText: preview,
            fullText: full,
            translation: selectedTranslation
        )
    }

    private func insertionText(for result: VerseResult) -> String {
        switch insertFormat {
        case .textOnly:
            return Self.extractBody(from: result.fullText)
        case .textAndReference:
            return result.fullText
        case .referenceOnly:
            return result.referenceLabel
        }
    }

    // MARK: - Intents

    public func onTapSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        presentation = .loading
        fetchTask?.cancel()
        uiState = .loadingSearch

        fetchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let selections = VerseSelection.fromQuery(trimmed)
            if selections.isEmpty {
                await MainActor.run {
                    self.errorMessage = "Invalid verse reference format"
                    self.uiState = .error(self.errorMessage ?? "Invalid input")
                }
                return
            }
            if selections.count == 1 {
                switch selections[0] {
                case let .single(book, chapter, verse):
                    let ref = VerseReference(book: book, chapter: chapter, startVerse: verse, endVerse: nil)
                    await MainActor.run { self.runFetchPipeline(reference: ref, loadingState: .loadingSearch, isBrowse: false) }

                case let .range(book, chapter, start, end):
                    do {
                        let verses = Array(start...end)
                        let fetched = try await self.fetchMultipleVerses(book: book, chapter: chapter, verses: verses, translation: self.selectedTranslation)
                        if Task.isCancelled { return }
                        let built = await MainActor.run { self.buildCombinedResult(book: book, chapter: chapter, verses: verses, fetched: fetched) }
                        await MainActor.run {
                            self.searchResult = built
                            self.browseResult = nil
                            self.uiState = .showingResult
                            self.presentation = .showingSearchResult
                            self.errorMessage = nil
                        }
                    } catch is CancellationError { } catch {
                        await MainActor.run {
                            self.errorMessage = Self.userFacingErrorMessage(error)
                            self.uiState = .error(self.errorMessage ?? "Unknown error")
                        }
                    }

                case let .chapter(book, chapter):
                    do {
                        let count = try await self.client.fetchChapterVerseCount(book: book, chapter: chapter)
                        if Task.isCancelled { return }
                        let verses = count > 0 ? Array(1...count) : []
                        let fetched = try await self.fetchMultipleVerses(book: book, chapter: chapter, verses: verses, translation: self.selectedTranslation)
                        if Task.isCancelled { return }
                        let built = await MainActor.run { self.buildCombinedResult(book: book, chapter: chapter, verses: verses, fetched: fetched) }
                        await MainActor.run {
                            self.searchResult = built
                            self.browseResult = nil
                            self.uiState = .showingResult
                            self.presentation = .showingSearchResult
                            self.errorMessage = nil
                        }
                    } catch is CancellationError { } catch {
                        await MainActor.run {
                            self.errorMessage = Self.userFacingErrorMessage(error)
                            self.uiState = .error(self.errorMessage ?? "Unknown error")
                        }
                    }

                case let .list(book, chapter, verses):
                    do {
                        let fetched = try await self.fetchMultipleVerses(book: book, chapter: chapter, verses: verses, translation: self.selectedTranslation)
                        if Task.isCancelled { return }
                        let built = await MainActor.run { self.buildCombinedResult(book: book, chapter: chapter, verses: verses, fetched: fetched) }
                        await MainActor.run {
                            self.searchResult = built
                            self.browseResult = nil
                            self.uiState = .showingResult
                            self.presentation = .showingSearchResult
                            self.errorMessage = nil
                        }
                    } catch is CancellationError { } catch {
                        await MainActor.run {
                            self.errorMessage = Self.userFacingErrorMessage(error)
                            self.uiState = .error(self.errorMessage ?? "Unknown error")
                        }
                    }
                }
            } else {
                // Multiple selections across chapters or mixed
                do {
                    let versesFetched = try await self.client.fetchComplexVerses(trimmed, translation: self.selectedTranslation)
                    if Task.isCancelled { return }
                    await MainActor.run {
                        let combinedFullText = self.formatter.formatPremiumMultiple(headerRef: trimmed, translation: self.selectedTranslation, verses: versesFetched)
                        let preview = KeyboardViewModel.previewBody(from: combinedFullText, limit: self.effectivePreviewLimit(for: self.previewLength))
                        let built = VerseResult(
                            referenceLabel: self.makeReferenceLabel(from: trimmed),
                            previewText: preview,
                            fullText: combinedFullText,
                            translation: self.selectedTranslation
                        )
                        self.searchResult = built
                        self.browseResult = nil
                        self.uiState = .showingResult
                        self.presentation = .showingSearchResult
                        self.errorMessage = nil
                    }
                } catch is CancellationError { } catch {
                    await MainActor.run {
                        self.errorMessage = Self.userFacingErrorMessage(error)
                        self.uiState = .error(self.errorMessage ?? "Unknown error")
                    }
                }
            }
        }
    }

    public func onTapMic() {
        if Bundle.main.bundlePath.hasSuffix(".appex") {
            errorMessage = "Voice input isn’t available in this keyboard. Type your reference."
            uiState = .error(errorMessage ?? "Voice unavailable")
            return
        }
        if uiState == .listening {
            onCancelVoice()
            return
        }
        fetchTask?.cancel()
        errorMessage = nil
        partialTranscript = nil
        uiState = .listening
        presentation = .listening
        speechService.start(
            onPartial: { [weak self] text in
                guard let self = self else { return }
                Task { @MainActor in
                    self.partialTranscript = text
                    if self.uiState != .listening { self.uiState = .listening }
                }
            },
            onFinal: { [weak self] text in
                guard let self = self else { return }
                Task { @MainActor in self.partialTranscript = nil }
                self.onTranscriptionResult(text)
            },
            onError: { [weak self] err in
                guard let self = self else { return }
                Task { @MainActor in
                    self.partialTranscript = nil
                    self.errorMessage = err.localizedDescription
                    self.uiState = .error(self.errorMessage ?? "Voice error")
                }
            }
        )
    }

    public func onCancelVoice() {
        fetchTask?.cancel()
        speechService.stop()
        partialTranscript = nil
        uiState = .idle
        presentation = .typing
    }

    public func onSendVoice() {
        speechService.stop()
        let transcript = self.partialTranscript ?? ""
        self.partialTranscript = nil
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.uiState = .idle
            return
        }
        self.onTranscriptionResult(trimmed)
    }

    public func onTranscriptionResult(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizeVoice(trimmed)
        guard !trimmed.isEmpty else { uiState = .idle; return }
        Task { @MainActor in self.partialTranscript = nil }
        fetchTask?.cancel()
        uiState = .processingVoice

        fetchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let selections = VerseSelection.fromQuery(normalized)
            if let only = selections.first, selections.count == 1 {
                switch only {
                case let .single(book, chapter, verse):
                    let ref = VerseReference(book: book, chapter: chapter, startVerse: verse, endVerse: nil)
                    await MainActor.run { self.runFetchPipeline(reference: ref, loadingState: .loadingSearch, isBrowse: false) }

                case let .range(book, chapter, start, end):
                    do {
                        let verses = Array(start...end)
                        let fetched = try await self.fetchMultipleVerses(book: book, chapter: chapter, verses: verses, translation: self.selectedTranslation)
                        if Task.isCancelled { return }
                        let built = await MainActor.run { self.buildCombinedResult(book: book, chapter: chapter, verses: verses, fetched: fetched) }
                        await MainActor.run {
                            self.searchResult = built
                            self.browseResult = nil
                            self.uiState = .showingResult
                            self.presentation = .showingSearchResult
                            self.errorMessage = nil
                        }
                    } catch is CancellationError { } catch {
                        await MainActor.run {
                            self.errorMessage = Self.userFacingErrorMessage(error)
                            self.uiState = .error(self.errorMessage ?? "Unknown error")
                        }
                    }

                case let .chapter(book, chapter):
                    do {
                        let count = try await self.client.fetchChapterVerseCount(book: book, chapter: chapter)
                        if Task.isCancelled { return }
                        let verses = count > 0 ? Array(1...count) : []
                        let fetched = try await self.fetchMultipleVerses(book: book, chapter: chapter, verses: verses, translation: self.selectedTranslation)
                        if Task.isCancelled { return }
                        let built = await MainActor.run { self.buildCombinedResult(book: book, chapter: chapter, verses: verses, fetched: fetched) }
                        await MainActor.run {
                            self.searchResult = built
                            self.browseResult = nil
                            self.uiState = .showingResult
                            self.presentation = .showingSearchResult
                            self.errorMessage = nil
                        }
                    } catch is CancellationError { } catch {
                        await MainActor.run {
                            self.errorMessage = Self.userFacingErrorMessage(error)
                            self.uiState = .error(self.errorMessage ?? "Unknown error")
                        }
                    }

                case let .list(book, chapter, verses):
                    do {
                        let fetched = try await self.fetchMultipleVerses(book: book, chapter: chapter, verses: verses, translation: self.selectedTranslation)
                        if Task.isCancelled { return }
                        let built = await MainActor.run { self.buildCombinedResult(book: book, chapter: chapter, verses: verses, fetched: fetched) }
                        await MainActor.run {
                            self.searchResult = built
                            self.browseResult = nil
                            self.uiState = .showingResult
                            self.presentation = .showingSearchResult
                            self.errorMessage = nil
                        }
                    } catch is CancellationError { } catch {
                        await MainActor.run {
                            self.errorMessage = Self.userFacingErrorMessage(error)
                            self.uiState = .error(self.errorMessage ?? "Unknown error")
                        }
                    }
                }
                return
            }

            // Not a direct reference: search then fetch
            do {
                let results = try await self.client.searchVerse(query: normalized, translation: self.selectedTranslation, limit: 1)
                if Task.isCancelled { return }
                if let top = results.first {
                    let verse = try await self.client.fetch(reference: top.reference, translation: self.selectedTranslation)
                    if Task.isCancelled { return }
                    await MainActor.run {
                        let full = self.formatter.formatPremiumSingle(verse)
                        let preview = KeyboardViewModel.previewBody(from: full, limit: self.effectivePreviewLimit(for: self.previewLength))
                        let refCore = "\(verse.reference.book) \(verse.reference.chapter):\(verse.reference.startVerse)"
                        let built = VerseResult(
                            referenceLabel: self.makeReferenceLabel(from: refCore),
                            previewText: preview,
                            fullText: full,
                            translation: self.selectedTranslation
                        )
                        self.searchResult = built
                        self.browseResult = nil
                        self.uiState = .showingResult
                        self.presentation = .showingSearchResult
                        self.errorMessage = nil
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "No matching verse found"
                        self.uiState = .error(self.errorMessage ?? "No match")
                    }
                }
            } catch is CancellationError { } catch {
                await MainActor.run {
                    self.errorMessage = Self.userFacingErrorMessage(error)
                    self.uiState = .error(self.errorMessage ?? "Unknown error")
                }
            }
        }
    }

    public func onSelectTranslation(_ t: Translation) {
        if selectedTranslation == t { return }
        selectedTranslation = t
        settings.defaultTranslation = t.rawValue.uppercased()

        switch mode {
        case .search:
            let trimmed = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                fetchTask?.cancel()
                uiState = .idle
                presentation = .typing
                return
            }
            self.fetchTask?.cancel()
            self.uiState = .loadingTranslationSwitch
            self.presentation = .loading
            self.fetchTask = Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let selections = VerseSelection.fromQuery(trimmed)
                if selections.isEmpty {
                    await MainActor.run {
                        self.uiState = .idle
                        self.presentation = .typing
                    }
                    return
                }
                if selections.count == 1 {
                    switch selections[0] {
                    case let .single(book, chapter, verse):
                        let ref = VerseReference(book: book, chapter: chapter, startVerse: verse, endVerse: nil)
                        await MainActor.run { self.runFetchPipeline(reference: ref, loadingState: .loadingTranslationSwitch, isBrowse: false) }

                    case let .range(book, chapter, start, end):
                        do {
                            let verses = Array(start...end)
                            let fetched = try await self.fetchMultipleVerses(book: book, chapter: chapter, verses: verses, translation: self.selectedTranslation)
                            if Task.isCancelled { return }
                            let built = await MainActor.run { self.buildCombinedResult(book: book, chapter: chapter, verses: verses, fetched: fetched) }
                            await MainActor.run {
                                self.searchResult = built
                                self.browseResult = nil
                                self.uiState = .showingResult
                                self.presentation = .showingSearchResult
                                self.errorMessage = nil
                            }
                        } catch is CancellationError { } catch {
                            await MainActor.run {
                                self.errorMessage = Self.userFacingErrorMessage(error)
                                self.uiState = .error(self.errorMessage ?? "Unknown error")
                            }
                        }

                    case let .chapter(book, chapter):
                        do {
                            let count = try await self.client.fetchChapterVerseCount(book: book, chapter: chapter)
                            if Task.isCancelled { return }
                            let verses = count > 0 ? Array(1...count) : []
                            let fetched = try await self.fetchMultipleVerses(book: book, chapter: chapter, verses: verses, translation: self.selectedTranslation)
                            if Task.isCancelled { return }
                            let built = await MainActor.run { self.buildCombinedResult(book: book, chapter: chapter, verses: verses, fetched: fetched) }
                            await MainActor.run {
                                self.searchResult = built
                                self.browseResult = nil
                                self.uiState = .showingResult
                                self.presentation = .showingSearchResult
                                self.errorMessage = nil
                            }
                        } catch is CancellationError { } catch {
                            await MainActor.run {
                                self.errorMessage = Self.userFacingErrorMessage(error)
                                self.uiState = .error(self.errorMessage ?? "Unknown error")
                            }
                        }

                    case let .list(book, chapter, verses):
                        do {
                            let fetched = try await self.fetchMultipleVerses(book: book, chapter: chapter, verses: verses, translation: self.selectedTranslation)
                            if Task.isCancelled { return }
                            let built = await MainActor.run { self.buildCombinedResult(book: book, chapter: chapter, verses: verses, fetched: fetched) }
                            await MainActor.run {
                                self.searchResult = built
                                self.browseResult = nil
                                self.uiState = .showingResult
                                self.presentation = .showingSearchResult
                                self.errorMessage = nil
                            }
                        } catch is CancellationError { } catch {
                            await MainActor.run {
                                self.errorMessage = Self.userFacingErrorMessage(error)
                                self.uiState = .error(self.errorMessage ?? "Unknown error")
                            }
                        }
                    }
                } else {
                    do {
                        let versesFetched = try await self.client.fetchComplexVerses(trimmed, translation: self.selectedTranslation)
                        if Task.isCancelled { return }
                        await MainActor.run {
                            let combinedFullText = self.formatter.formatPremiumMultiple(headerRef: trimmed, translation: self.selectedTranslation, verses: versesFetched)
                            let preview = KeyboardViewModel.previewBody(from: combinedFullText, limit: self.effectivePreviewLimit(for: self.previewLength))
                            let built = VerseResult(
                                referenceLabel: self.makeReferenceLabel(from: trimmed),
                                previewText: preview,
                                fullText: combinedFullText,
                                translation: self.selectedTranslation
                            )
                            self.searchResult = built
                            self.browseResult = nil
                            self.uiState = .showingResult
                            self.presentation = .showingSearchResult
                            self.errorMessage = nil
                        }
                    } catch is CancellationError { } catch {
                        await MainActor.run {
                            self.errorMessage = Self.userFacingErrorMessage(error)
                            self.uiState = .error(self.errorMessage ?? "Unknown error")
                        }
                    }
                }
            }
        case .browse:
            if let res = browseResult {
                fetchTask?.cancel()
                uiState = .loadingTranslationSwitch
                presentation = .loading
                fetchTask = Task.detached(priority: .userInitiated) { [weak self] in
                    guard let self else { return }
                    let core = res.referenceLabel.components(separatedBy: " (").first ?? res.referenceLabel
                    if core.contains(",") {
                        do {
                            let refs = try VerseParser.parseComplexVerses(core)
                            guard let first = refs.first else {
                                await MainActor.run {
                                    self.uiState = .idle
                                    self.presentation = .typing
                                }
                                return
                            }
                            let book = first.book
                            let chapter = first.chapter
                            let verses = refs.map { $0.startVerse }.sorted()
                            let fetched = try await self.fetchMultipleVerses(book: book, chapter: chapter, verses: verses, translation: self.selectedTranslation)
                            if Task.isCancelled { return }
                            let built = await MainActor.run { self.buildCombinedResult(book: book, chapter: chapter, verses: verses, fetched: fetched) }
                            await MainActor.run {
                                self.browseResult = built
                                self.searchResult = nil
                                self.uiState = .showingResult
                                self.presentation = .showingBrowseResult
                                self.errorMessage = nil
                            }
                        } catch is CancellationError { } catch {
                            await MainActor.run {
                                self.errorMessage = Self.userFacingErrorMessage(error)
                                self.uiState = .error(self.errorMessage ?? "Unknown error")
                            }
                        }
                    } else {
                        if let ref = try? VerseParser.parse(core) {
                            if let end = ref.endVerse, end >= ref.startVerse {
                                do {
                                    let verses = Array(ref.startVerse...end)
                                    let fetched = try await self.fetchMultipleVerses(book: ref.book, chapter: ref.chapter, verses: verses, translation: self.selectedTranslation)
                                    if Task.isCancelled { return }
                                    let built = await MainActor.run { self.buildCombinedResult(book: ref.book, chapter: ref.chapter, verses: verses, fetched: fetched) }
                                    await MainActor.run {
                                        self.browseResult = built
                                        self.searchResult = nil
                                        self.uiState = .showingResult
                                        self.presentation = .showingBrowseResult
                                        self.errorMessage = nil
                                    }
                                } catch is CancellationError { } catch {
                                    await MainActor.run {
                                        self.errorMessage = Self.userFacingErrorMessage(error)
                                        self.uiState = .error(self.errorMessage ?? "Unknown error")
                                    }
                                }
                            } else {
                                await MainActor.run {
                                    self.runFetchPipeline(reference: ref, loadingState: .loadingTranslationSwitch, isBrowse: true)
                                }
                            }
                        } else {
                            await MainActor.run {
                                self.uiState = .idle
                                self.presentation = .typing
                            }
                        }
                    }
                }
                return
            }

            if let book = selectedBook, let chapter = selectedChapter, let verse = selectedVerse {
                let ref = VerseReference(book: book, chapter: chapter, startVerse: verse, endVerse: nil)
                presentation = .loading
                runFetchPipeline(reference: ref, loadingState: .loadingTranslationSwitch, isBrowse: true)
            } else if let _ = selectedBook, let _ = selectedChapter {
                presentation = .loading
                loadVerseCountForSelectedChapter()
            } else {
                uiState = .idle
                presentation = .typing
            }
        }
    }

    public func updatePreviewLength(from value: Int) {
        if value <= 140 {
            self.previewLength = .short
        } else if value <= 220 {
            self.previewLength = .medium
        } else {
            self.previewLength = .long
        }
        settings.previewLength = value
    }

    public func setInsertFormat(_ format: InsertFormat) {
        self.insertFormat = format
        settings.insertFormat = SettingsStore.InsertFormat(rawValue: format.rawValue) ?? .textAndReference
    }

    public func onSwitchMode(_ m: KeyboardMode) {
        guard mode != m else { return }
        fetchTask?.cancel()
        mode = m
        if m == .browse {
            inputFocus = .host
        }
        errorMessage = nil
        uiState = .idle
        presentation = .typing
    }

    public func onToggleWholeChapterMode() {
        isWholeChapterMode.toggle()
        if isWholeChapterMode {
            selectedVerse = nil
            selectedVersesSet.removeAll()
        }
    }

    public func onBrowseSelectBook(_ book: String) {
        if book.isEmpty {
            selectedBook = nil
            selectedChapter = nil
            selectedVerse = nil
        } else {
            selectedBook = book
            selectedChapter = nil
            selectedVerse = nil
        }
        currentChapterVerseCount = 0
        browseResult = nil
        uiState = .idle
        presentation = .typing
        selectedVersesSet.removeAll()
        isMultiSelectEnabled = false
    }

    public func onBrowseSelectChapter(_ chapter: Int) {
        if chapter <= 0 {
            selectedChapter = nil
            selectedVerse = nil
            currentChapterVerseCount = 0
        } else {
            if isWholeChapterMode {
                isWholeChapterMode = false
                selectedChapter = nil
                selectedVerse = nil
                currentChapterVerseCount = 0
                browseResult = nil
                selectedVersesSet.removeAll()
                isMultiSelectEnabled = false
                if let book = selectedBook {
                    fetchWholeChapter(book: book, chapter: chapter)
                }
                return
            }

            selectedChapter = chapter
            selectedVerse = nil
            currentChapterVerseCount = 0
            presentation = .loading
            loadVerseCountForSelectedChapter()
        }
        browseResult = nil
        uiState = .idle
        presentation = .typing
        selectedVersesSet.removeAll()
        isMultiSelectEnabled = false
    }

    private func loadVerseCountForSelectedChapter() {
        guard let book = selectedBook, let ch = selectedChapter, ch > 0 else { return }
        fetchTask?.cancel()
        currentChapterVerseCount = 0
        errorMessage = nil
        fetchTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                let count = try await self.client.fetchChapterVerseCount(book: book, chapter: ch)
                if Task.isCancelled { return }
                await MainActor.run { self.currentChapterVerseCount = max(count, 0) }
            } catch {
                await MainActor.run {
                    self.currentChapterVerseCount = -1
                    self.errorMessage = Self.userFacingErrorMessage(error)
                    self.uiState = .error(self.errorMessage ?? "Could not load verses")
                }
            }
        }
    }

    public func onBrowseSelectVerse(_ verse: Int) {
        if isMultiSelectEnabled {
            if selectedVersesSet.contains(verse) {
                selectedVersesSet.remove(verse)
            } else {
                selectedVersesSet.insert(verse)
            }
            return
        }
        selectedVerse = verse
        guard let book = selectedBook, let ch = selectedChapter else { return }
        presentation = .loading
        let ref = VerseReference(book: book, chapter: ch, startVerse: verse, endVerse: nil)
        runFetchPipeline(reference: ref, loadingState: .loadingSearch, isBrowse: true)
    }

    public func onTapResultCardToInsert() {
        if mode == .browse {
            guard let res = browseResult else { return }
            let insertedText = insertionText(for: res)
            if hapticsEnabled {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            inserter.insert(insertedText)
            historyStore.append(
                selectionDescription: res.referenceLabel,
                translation: res.translation.displayCode,
                insertedText: insertedText
            )
            if mode == .browse {
                returnToTyping(forceSearchMode: true)
            } else {
                returnToTyping()
            }
        } else {
            guard let res = searchResult else { return }
            let insertedText = insertionText(for: res)
            if hapticsEnabled {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            inserter.insert(insertedText)
            historyStore.append(
                selectionDescription: res.referenceLabel,
                translation: res.translation.displayCode,
                insertedText: insertedText
            )
            if mode == .browse {
                returnToTyping(forceSearchMode: true)
            } else {
                returnToTyping()
            }
        }
    }

    public func maintainTypingGlow(_ active: Bool) {
        uiState = active ? .typingGlow : .idle
    }

    public func onToggleMultiSelect() {
        if isMultiSelectEnabled {
            selectedVersesSet.removeAll()
            isMultiSelectEnabled = false
        } else {
            selectedVerse = nil
            selectedVersesSet.removeAll()
            isMultiSelectEnabled = true
        }
    }

    public func onFetchSelectedVerses() {
        guard let book = selectedBook, let chapter = selectedChapter, !selectedVersesSet.isEmpty else { return }
        let verses = selectedVersesSet.sorted()
        fetchTask?.cancel()

        uiState = .loadingSearch
        presentation = .loading
        fetchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let fetched = try await self.fetchMultipleVerses(book: book, chapter: chapter, verses: verses, translation: self.selectedTranslation)
                if Task.isCancelled { return }
                let built = await MainActor.run { self.buildCombinedResult(book: book, chapter: chapter, verses: verses, fetched: fetched) }
                await MainActor.run {
                    self.browseResult = built
                    self.searchResult = nil
                    self.uiState = .showingResult
                    self.presentation = .showingBrowseResult
                    self.errorMessage = nil
                    self.selectedVersesSet.removeAll()
                }
            } catch is CancellationError { } catch {
                await MainActor.run {
                    self.errorMessage = Self.userFacingErrorMessage(error)
                    self.uiState = .error(self.errorMessage ?? "Unknown error")
                }
            }
        }
    }

    public func onFetchWholeChapter() {
        guard let book = selectedBook, let chapter = selectedChapter else { return }
        fetchWholeChapter(book: book, chapter: chapter)
    }

    private func fetchWholeChapter(book: String, chapter: Int) {
        fetchTask?.cancel()

        uiState = .loadingSearch
        presentation = .loading
        fetchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let count = try await self.client.fetchChapterVerseCount(book: book, chapter: chapter)
                if Task.isCancelled { return }
                let verses = count > 0 ? Array(1...count) : []
                let fetched = try await self.fetchMultipleVerses(book: book, chapter: chapter, verses: verses, translation: self.selectedTranslation)
                if Task.isCancelled { return }
                let built = await MainActor.run { self.buildCombinedResult(book: book, chapter: chapter, verses: verses, fetched: fetched) }
                await MainActor.run {
                    self.browseResult = built
                    self.searchResult = nil
                    self.uiState = .showingResult
                    self.presentation = .showingBrowseResult
                    self.errorMessage = nil
                    self.selectedChapter = nil
                    self.selectedVerse = nil
                    self.currentChapterVerseCount = 0
                    self.selectedVersesSet.removeAll()
                    self.isMultiSelectEnabled = false
                    self.isWholeChapterMode = false
                }
            } catch is CancellationError { } catch {
                await MainActor.run {
                    self.errorMessage = Self.userFacingErrorMessage(error)
                    self.selectedChapter = nil
                    self.selectedVerse = nil
                    self.currentChapterVerseCount = 0
                    self.uiState = .error(self.errorMessage ?? "Unknown error")
                }
            }
        }
    }

    public func enterSearchFocus() {
        inputFocus = .search
        presentation = .typing
    }

    public func releaseToHost() {
        inputFocus = .host
    }

    public func returnToTyping(forceSearchMode: Bool = false) {
        presentation = .typing
        if forceSearchMode { mode = .search }
    }
}
