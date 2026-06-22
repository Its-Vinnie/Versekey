import Foundation

/// Client for https://api.scripture.api.bible (API.Bible)
nonisolated public struct APIBibleComClient: VerseAPIClient {
    private let session: URLSession
    private let apiKey: String
    private let baseURL = URL(string: "https://rest.api.bible/v1")!

    // Map Translation to API.Bible bibleId
    // Only include the IDs the user explicitly provided
    private let bibleIds: [Translation: String] = [
        .niv: "78a9f6124f344018-01",
        .csb: "a556c5305ee15c3f-01",
        .nkjv: "63097d2a0a2f7db3-01",
        .kjv: "55212e3cf5d04d49-01", //newly added
        .web: "9879dbb7cfe39e4d-01", //newly added
        .webbe: "7142879509583d59-01", //newly added
        .webus: "32664dc3288a28df-01", //newly added
        .nasb1995:"b8ee27bcd1cae43a-01", //newly added
        .asv: "06125adad2d5898a-01", //newly added
        .nlt: "d6e14a625393b4da-01",
        .amp: "a81b73293d3080c9-01",
        .msg: "6f11a7de016f942e-01"
    ]

    public init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey
            ?? (Bundle.main.object(forInfoDictionaryKey: "APIBibleComAPIKey") as? String)
            ?? ""
        self.session = session
    }

    public func fetch(reference: VerseReference, translation: Translation) async throws -> VerseText {
        guard !apiKey.isEmpty else { throw APIError.authenticationFailed }
        guard let bibleId = bibleIds[translation] else {
            throw APIError.unsupportedTranslation
        }
        // Check for whole-chapter request
        if reference.endVerse == 999 {
            return try await fetchWholeChapter(reference: reference, translation: translation, bibleId: bibleId)
        }
        // Build passageId in API.Bible canonical format, e.g. GEN.1.1 or GEN.1.1-GEN.1.5
        let passageId = try passageIdFor(reference)
        var components = apiURLComponents(path: "/v1/bibles/\(bibleId)/passages/\(passageId)")
        components.queryItems = [
            URLQueryItem(name: "content-type", value: "text"),
            URLQueryItem(name: "include-verse-numbers", value: "true"),
            URLQueryItem(name: "include-chapter-numbers", value: "false"),
            URLQueryItem(name: "include-notes", value: "false")
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 404 {
            throw VerseParseError.verseNotFound("Verse or passage not found for \(reference.book) \(reference.chapter)")
        }
        guard http.statusCode == 200 else { throw APIError.httpError(http.statusCode) }

        // Decode according to BibleAPIGuide.json: data -> Passage, meta -> Meta
        struct APIResponse: Decodable { let data: PassagePayload }
        struct PassagePayload: Decodable { let id: String; let bibleId: String; let content: String; let reference: String }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        let rawHTML = decoded.data.content
        let regexPattern = "<[^>]+>"
        let stripped = rawHTML.replacingOccurrences(of: regexPattern, with: "", options: .regularExpression)
        let text = stripped.trimmingCharacters(in: .whitespacesAndNewlines)

        return VerseText(reference: reference, translation: translation, text: text)
    }

    public func searchVerse(query: String, translation: Translation, limit: Int = 5) async throws -> [VerseText] {
        guard !apiKey.isEmpty else { throw APIError.authenticationFailed }
        guard let bibleId = bibleIds[translation] else { throw APIError.unsupportedTranslation }
        var components = apiURLComponents(path: "/v1/bibles/\(bibleId)/search")
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "sort", value: "relevance")
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 404 {
            return []
        }
        guard http.statusCode == 200 else { throw APIError.httpError(http.statusCode) }

        // According to BibleAPIGuide: response has data -> SearchResponse
        struct SearchAPIResponse: Decodable { let data: SearchPayload }
        struct SearchPayload: Decodable {
            let query: String
            let limit: Int
            let offset: Int
            let total: Int
            let verseCount: Int
            let verses: [SearchVerse]
        }
        struct SearchVerse: Decodable { let text: String?; let reference: String }

        let decoded = try JSONDecoder().decode(SearchAPIResponse.self, from: data)
        var results: [VerseText] = []
        for v in decoded.data.verses {
            let raw = v.text ?? ""
            let regex = "<[^>]+>"
            let noTags = raw.replacingOccurrences(of: regex, with: "", options: .regularExpression)
            let clean = noTags.trimmingCharacters(in: .whitespacesAndNewlines)
            if let ref = try? VerseParser.parse(v.reference) {
                results.append(VerseText(reference: ref, translation: translation, text: clean))
            }
        }
        return results
    }

    private func apiURLComponents(path: String) -> URLComponents {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        return components
    }

    private func passageIdFor(_ reference: VerseReference) throws -> String {
        let bookAbbr = try apiBibleBookAbbreviation(for: reference.book)
        if let end = reference.endVerse {
            return "\(bookAbbr).\(reference.chapter).\(reference.startVerse)-\(bookAbbr).\(reference.chapter).\(end)"
        } else {
            return "\(bookAbbr).\(reference.chapter).\(reference.startVerse)"
        }
    }

    private func apiBibleBookAbbreviation(for name: String) throws -> String {
        // Map canonical names to API.Bible abbreviations
        let map: [String: String] = [
            "Genesis": "GEN", "Exodus": "EXO", "Leviticus": "LEV", "Numbers": "NUM", "Deuteronomy": "DEU",
            "Joshua": "JOS", "Judges": "JDG", "Ruth": "RUT", "1 Samuel": "1SA", "2 Samuel": "2SA",
            "1 Kings": "1KI", "2 Kings": "2KI", "1 Chronicles": "1CH", "2 Chronicles": "2CH",
            "Ezra": "EZR", "Nehemiah": "NEH", "Esther": "EST", "Job": "JOB", "Psalms": "PSA",
            "Proverbs": "PRO", "Ecclesiastes": "ECC", "Song of Solomon": "SNG", "Isaiah": "ISA",
            "Jeremiah": "JER", "Lamentations": "LAM", "Ezekiel": "EZK", "Daniel": "DAN",
            "Hosea": "HOS", "Joel": "JOL", "Amos": "AMO", "Obadiah": "OBA", "Jonah": "JON",
            "Micah": "MIC", "Nahum": "NAM", "Habakkuk": "HAB", "Zephaniah": "ZEP", "Haggai": "HAG",
            "Zechariah": "ZEC", "Malachi": "MAL", "Matthew": "MAT", "Mark": "MRK", "Luke": "LUK",
            "John": "JHN", "Acts": "ACT", "Romans": "ROM", "1 Corinthians": "1CO", "2 Corinthians": "2CO",
            "Galatians": "GAL", "Ephesians": "EPH", "Philippians": "PHP", "Colossians": "COL",
            "1 Thessalonians": "1TH", "2 Thessalonians": "2TH", "1 Timothy": "1TI", "2 Timothy": "2TI",
            "Titus": "TIT", "Philemon": "PHM", "Hebrews": "HEB", "James": "JAS", "1 Peter": "1PE",
            "2 Peter": "2PE", "1 John": "1JN", "2 John": "2JN", "3 John": "3JN", "Jude": "JUD",
            "Revelation": "REV"
        ]
        guard let abbr = map[name] else { throw VerseParseError.unknownBook }
        return abbr
    }

    private func fetchWholeChapter(reference: VerseReference, translation: Translation, bibleId: String) async throws -> VerseText {
        let bookAbbr = try apiBibleBookAbbreviation(for: reference.book)
        let chapterId = "\(bookAbbr).\(reference.chapter)"
        var components = apiURLComponents(path: "/v1/bibles/\(bibleId)/chapters/\(chapterId)")
        components.queryItems = [
            URLQueryItem(name: "content-type", value: "text"),
            URLQueryItem(name: "include-verse-numbers", value: "true"),
            URLQueryItem(name: "include-chapter-numbers", value: "false"),
            URLQueryItem(name: "include-notes", value: "false")
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard http.statusCode == 200 else { throw APIError.httpError(http.statusCode) }

        struct ChapterAPIResponse: Decodable { let data: ChapterPayload }
        struct ChapterPayload: Decodable { let content: String }

        let decoded = try JSONDecoder().decode(ChapterAPIResponse.self, from: data)
        let rawHTML = decoded.data.content
        let regexPattern = "<[^>]+>"
        let stripped = rawHTML.replacingOccurrences(of: regexPattern, with: "", options: .regularExpression)
        let text = stripped.trimmingCharacters(in: .whitespacesAndNewlines)

        let verseCount = try await getChapterVerseCount(book: reference.book, chapter: reference.chapter)
        let adjustedRef = VerseReference(book: reference.book, chapter: reference.chapter, startVerse: 1, endVerse: verseCount)
        return VerseText(reference: adjustedRef, translation: translation, text: text)
    }

    public func getChapterVerseCount(book: String, chapter: Int) async throws -> Int {
        guard !apiKey.isEmpty else { throw APIError.authenticationFailed }
        // Verse counts are stable across translations; use a public-domain Bible ID for this metadata lookup.
        guard let bibleId = bibleIds[.kjv] ?? bibleIds[.web] ?? bibleIds.values.first else { throw APIError.unsupportedTranslation }
        let bookAbbr = try apiBibleBookAbbreviation(for: book)
        let chapterId = "\(bookAbbr).\(chapter)"
        var components = apiURLComponents(path: "/v1/bibles/\(bibleId)/chapters/\(chapterId)")
        components.queryItems = [
            URLQueryItem(name: "content-type", value: "json"),
            URLQueryItem(name: "include-verse-numbers", value: "false"),
            URLQueryItem(name: "include-chapter-numbers", value: "false"),
            URLQueryItem(name: "include-notes", value: "false")
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard http.statusCode == 200 else { throw APIError.httpError(http.statusCode) }

        struct ChapterAPIResponse: Decodable { let data: ChapterPayload }
        struct ChapterPayload: Decodable { let verseCount: Int }

        let decoded = try JSONDecoder().decode(ChapterAPIResponse.self, from: data)
        return decoded.data.verseCount
    }
}
