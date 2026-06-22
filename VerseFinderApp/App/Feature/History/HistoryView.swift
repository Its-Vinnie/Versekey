import SwiftUI

struct HistoryView: View {
    let history: HistoryStore
    @State private var items: [HistoryStore.Item] = []
    @State private var selected: HistoryStore.Item? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.historyScreenBackground.ignoresSafeArea()

                if items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ForEach(grouped(items), id: \.0) { section, rows in
                                VStack(alignment: .leading, spacing: 14) {
                                    Text(section)
                                        .font(.system(size: 21, weight: .semibold))
                                        .foregroundStyle(Color.historyMuted)
                                        .padding(.horizontal, 20)

                                    LazyVStack(spacing: 22) {
                                        ForEach(rows) { item in
                                            HistoryCard(
                                                item: item,
                                                time: shortTime(item.timestamp),
                                                onTap: { selected = item },
                                                onCopy: { UIPasteboard.general.string = item.insertedText },
                                                onDelete: { delete(item) }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("History")
            .onAppear { reload() }
            .sheet(item: $selected) { it in
                HistoryDetailView(item: it)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Color.historyMuted)
            Text("No History Yet")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(Color.primary)
            Text("Verses you insert will appear here.")
                .font(.system(size: 15))
                .foregroundStyle(Color.historyMuted)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 36)
    }

    private func reload() { items = history.load() }

    private func delete(_ item: HistoryStore.Item) {
        // Simple delete by rewriting without the item
        var current = history.load()
        current.removeAll { $0.id == item.id }
        do {
            let data = try JSONEncoder().encode(current)
            try data.write(to: AppGroup.containerURL.appendingPathComponent("history.json"), options: [.atomic])
            reload()
        } catch { }
    }

    private func grouped(_ items: [HistoryStore.Item]) -> [(String, [HistoryStore.Item])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        var todayItems: [HistoryStore.Item] = []
        var yesterdayItems: [HistoryStore.Item] = []
        var earlier: [HistoryStore.Item] = []
        for it in items {
            let d = cal.startOfDay(for: it.timestamp)
            if d >= today { todayItems.append(it) }
            else if d >= yesterday { yesterdayItems.append(it) }
            else { earlier.append(it) }
        }
        var result: [(String, [HistoryStore.Item])] = []
        if !todayItems.isEmpty { result.append(("Today", todayItems)) }
        if !yesterdayItems.isEmpty { result.append(("Yesterday", yesterdayItems)) }
        if !earlier.isEmpty { result.append(("Earlier", earlier)) }
        return result
    }

    private func shortTime(_ date: Date) -> String { let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f.string(from: date) }
}

private struct HistoryCard: View {
    let item: HistoryStore.Item
    let time: String
    let onTap: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Label {
                        Text(historyReference(for: item))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.accentBlue)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "book.closed")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.accentBlue.opacity(0.9))
                    }
                    .labelStyle(.titleAndIcon)

                    Spacer(minLength: 12)

                    Text(time)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.historyMuted)
                        .lineLimit(1)
                }

                Text(historyTranslation(for: item))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.historyBadgeText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.historyBadgeBackground, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.historyBadgeBorder, lineWidth: 1)
                    )

                Text(historyBody(for: item))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.historyVerse)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.historyCard, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.historyCardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { onCopy() }
            Button("Delete", systemImage: "trash", role: .destructive) { onDelete() }
        }
    }
}

struct HistoryDetailView: View {
    let item: HistoryStore.Item
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(historyTitle(for: item))
                        .font(.headline)
                    Text(historyBody(for: item))
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Copy") { UIPasteboard.general.string = item.insertedText }
                }
            }
            .navigationTitle("Verse")
        }
    }
}

private func historyTitle(for item: HistoryStore.Item) -> String {
    let title = item.selectionDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    let translation = item.translation.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !translation.isEmpty else { return title }
    if title.uppercased().contains("(\(translation))") || title.uppercased().hasSuffix("— \(translation)") {
        return title
    }
    return "\(title) — \(translation)"
}

private func historyReference(for item: HistoryStore.Item) -> String {
    let title = item.selectionDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    let translation = item.translation.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !translation.isEmpty else { return title }

    return title
        .replacingOccurrences(of: "— \(translation)", with: "")
        .replacingOccurrences(of: "- \(translation)", with: "")
        .replacingOccurrences(of: "(\(translation))", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func historyTranslation(for item: HistoryStore.Item) -> String {
    switch item.translation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "nasb2020":
        return "NASB20"
    case "nasb1995":
        return "NASB95"
    default:
        return item.translation.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}

private func historyBody(for item: HistoryStore.Item) -> String {
    let title = item.selectionDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    var body = item.insertedText.trimmingCharacters(in: .whitespacesAndNewlines)

    if !title.isEmpty, body.hasPrefix(title) {
        body.removeFirst(title.count)
        body = body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let decoratedTitle = historyTitle(for: item)
    if body.hasPrefix(decoratedTitle) {
        body.removeFirst(decoratedTitle.count)
        body = body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return body.isEmpty ? item.insertedText : body
}

private extension Color {
    static let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let historyScreenBackground = Color(uiColor: .systemBackground)
    static let historyCard = Color(uiColor: .secondarySystemBackground)
    static let historyCardBorder = Color(uiColor: .separator).opacity(0.32)
    static let historyMuted = Color(uiColor: .secondaryLabel)
    static let historyVerse = Color(uiColor: .secondaryLabel)
    static let historyBadgeText = Color(uiColor: .label)
    static let historyBadgeBackground = Color(uiColor: .tertiarySystemFill)
    static let historyBadgeBorder = Color(uiColor: .separator).opacity(0.24)
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(history: HistoryStore())
    }
}
