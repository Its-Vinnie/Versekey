//
//  HistoryStore.swift
//  VerseFinderApp
//
//  Created by Assistant on 2026/03/05.
//

import Foundation

/// A lightweight history store that persists recent verse fetches/insertions
/// as a small JSON file under the shared App Group container.
public final class HistoryStore: @unchecked Sendable {
    public struct Item: Codable, Identifiable, Equatable, Sendable {
        public let id: UUID
        public let timestamp: Date
        public let selectionDescription: String // e.g., "John 3:16"
        public let translation: String // e.g., "NIV"
        public let insertedText: String // full text that was inserted
    }

    private let fileURL: URL
    private let queue = DispatchQueue(label: "HistoryStore.queue", qos: .utility)

    public init(filename: String = "history.json") {
        self.fileURL = AppGroup.containerURL.appendingPathComponent(filename)
    }

    public func load(limit: Int = 100) -> [Item] {
        do {
            let data = try Data(contentsOf: fileURL)
            var items = try JSONDecoder().decode([Item].self, from: data)
            // Keep most recent first
            items.sort { $0.timestamp > $1.timestamp }
            if items.count > limit { items = Array(items.prefix(limit)) }
            return items
        } catch {
            return []
        }
    }

    public func append(selectionDescription: String, translation: String, insertedText: String, limit: Int = 100) {
        queue.async {
            var items = self.load(limit: limit)
            items.insert(Item(id: UUID(), timestamp: Date(), selectionDescription: selectionDescription, translation: translation, insertedText: insertedText), at: 0)
            // Truncate to limit
            if items.count > limit { items = Array(items.prefix(limit)) }
            do {
                let data = try JSONEncoder().encode(items)
                try data.write(to: self.fileURL, options: [.atomic])
            } catch {
                // Swallow in production; consider logging
            }
        }
    }
}
