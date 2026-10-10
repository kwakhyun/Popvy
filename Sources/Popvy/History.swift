import AppKit
import Combine
import CryptoKit

struct ClipboardRepresentation: Codable, Equatable {
    let type: String
    let data: Data
}

struct ClipboardEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let fingerprint: String
    var createdAt: Date
    let text: String
    let isImage: Bool
    let source: String
    let representations: [ClipboardRepresentation]
    var isPinned: Bool

    init(text: String, isImage: Bool = false, source: String = "", representations: [ClipboardRepresentation],
         createdAt: Date = Date(), isPinned: Bool = false) {
        self.id = UUID()
        self.createdAt = createdAt
        self.text = text
        self.isImage = isImage
        self.source = source
        self.representations = representations
        self.isPinned = isPinned
        var hash = SHA256()
        for representation in representations.sorted(by: { $0.type < $1.type }) {
            hash.update(data: Data(representation.type.utf8))
            hash.update(data: Data([0]))
            hash.update(data: representation.data)
        }
        fingerprint = hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    var byteCount: Int { representations.reduce(0) { $0 + $1.data.count } }
    var preview: String {
        if isImage { return "이미지" }
        return text.split(whereSeparator: \.isNewline).prefix(3).joined(separator: " ")
    }
    var image: NSImage? {
        guard isImage, let data = representations.first(where: {
            $0.type == NSPasteboard.PasteboardType.png.rawValue || $0.type == NSPasteboard.PasteboardType.tiff.rawValue
        })?.data else { return nil }
        return NSImage(data: data)
    }
    var isLink: Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.contains(where: \.isWhitespace), let url = URL(string: value) else { return false }
        return ["https", "http"].contains(url.scheme?.lowercased() ?? "")
    }
}

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "전체", text = "텍스트", images = "이미지", pinned = "고정"
    var id: String { rawValue }
}

final class HistoryStore: ObservableObject {
    static let maxItems = 100
    static let maxPins = 20
    static let maxItemBytes = 5 * 1024 * 1024
    static let maxTotalBytes = 50 * 1024 * 1024
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published private(set) var persistenceError: String?
    private let fileURL: URL?
    private let queue = DispatchQueue(label: "app.popvy.history", qos: .utility)
    private var saveWork: DispatchWorkItem?
    var persistenceEnabled: Bool {
        didSet {
            saveWork?.cancel()
            if persistenceEnabled { persist() }
            else if let fileURL {
                queue.sync {
                    do {
                        if FileManager.default.fileExists(atPath: fileURL.path) {
                            try FileManager.default.removeItem(at: fileURL)
                        }
                        persistenceError = nil
                    } catch { persistenceError = "저장된 기록을 지우지 못했습니다: \(error.localizedDescription)" }
                }
            }
        }
    }

    private struct Archive: Codable {
        let version: Int
        let entries: [ClipboardEntry]
    }

    init(fileURL: URL?, persistenceEnabled: Bool = true) {
        self.fileURL = fileURL
        self.persistenceEnabled = persistenceEnabled
        guard persistenceEnabled, let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) <= Self.maxTotalBytes * 2 else {
                throw CocoaError(.fileReadTooLarge)
            }
            let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: fileURL))
            guard archive.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
            entries = archive.entries.filter { !$0.representations.isEmpty && $0.byteCount <= Self.maxItemBytes }
            // Bound a loaded archive just like freshly captured entries.
            var pins = 0
            for index in entries.indices where entries[index].isPinned {
                pins += 1
                if pins > Self.maxPins { entries[index].isPinned = false }
            }
            trim()
        } catch {
            persistenceError = "이전 기록을 불러오지 못했습니다. 새 기록부터 표시합니다."
        }
    }

    func add(_ entry: ClipboardEntry) {
        guard !entry.representations.isEmpty, entry.byteCount <= Self.maxItemBytes else { return }
        if let index = entries.firstIndex(where: { $0.fingerprint == entry.fingerprint }) {
            var existing = entries.remove(at: index)
            existing.createdAt = entry.createdAt
            entries.insert(existing, at: 0)
        } else {
            entries.insert(entry, at: 0)
        }
        trim()
        persist()
    }

    @discardableResult
    func togglePin(_ id: UUID) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        guard entries[index].isPinned || entries.filter(\.isPinned).count < Self.maxPins else { return false }
        entries[index].isPinned.toggle()
        persist()
        return true
    }

    func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func clear(includingPinned: Bool = false) {
        entries.removeAll { includingPinned || !$0.isPinned }
        persist()
    }

    func filtered(query: String, filter: HistoryFilter) -> [ClipboardEntry] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter { entry in
            let matchesType: Bool
            switch filter {
            case .all: matchesType = true
            case .text: matchesType = !entry.isImage
            case .images: matchesType = entry.isImage
            case .pinned: matchesType = entry.isPinned
            }
            return matchesType && (query.isEmpty || entry.text.localizedStandardContains(query)
                || entry.source.localizedStandardContains(query) || (entry.isImage && "이미지".contains(query)))
        }.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.createdAt > b.createdAt
        }
    }

    private func trim() {
        var total = entries.reduce(0) { $0 + $1.byteCount }
        while entries.count > Self.maxItems || total > Self.maxTotalBytes {
            // A malformed archive must not bypass the storage budget through pinned items.
            guard let index = entries.lastIndex(where: { !$0.isPinned }) ?? entries.indices.last else { break }
            total -= entries[index].byteCount
            entries.remove(at: index)
        }
    }

    private func persist() {
        guard persistenceEnabled, let fileURL else { return }
        saveWork?.cancel()
        let snapshot = entries
        let work = DispatchWorkItem { [weak self] in
            do {
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let data = try JSONEncoder().encode(Archive(version: 1, entries: snapshot))
                try data.write(to: fileURL, options: [.atomic])
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
                DispatchQueue.main.async { self?.persistenceError = nil }
            } catch {
                DispatchQueue.main.async { self?.persistenceError = "기록 저장 실패: \(error.localizedDescription)" }
            }
        }
        saveWork = work
        queue.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    func flush() {
        saveWork?.cancel()
        guard persistenceEnabled, let fileURL else { return }
        let snapshot = entries
        queue.sync {
            do {
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                try JSONEncoder().encode(Archive(version: 1, entries: snapshot)).write(to: fileURL, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            } catch { persistenceError = "기록 저장 실패: \(error.localizedDescription)" }
        }
    }
}
