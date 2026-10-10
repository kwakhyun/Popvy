import AppKit
import XCTest
@testable import Popvy

final class HistoryTests: XCTestCase {
    private func entry(_ text: String, pinned: Bool = false, date: Date = Date()) -> ClipboardEntry {
        ClipboardEntry(text: text, source: "테스트", representations: [
            .init(type: NSPasteboard.PasteboardType.string.rawValue, data: Data(text.utf8))
        ], createdAt: date, isPinned: pinned)
    }

    func testDuplicateKeepsIdentityAndPinAndMovesToNewest() {
        let store = HistoryStore(fileURL: nil)
        let original = entry("반복 복사", pinned: true, date: Date(timeIntervalSince1970: 1))
        store.add(original)
        store.add(entry("다른 기록"))
        store.add(entry("반복 복사"))
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.entries.first?.id, original.id)
        XCTAssertEqual(store.entries.first?.isPinned, true)
        XCTAssertGreaterThan(store.entries.first!.createdAt, original.createdAt)
    }

    func testHistoryLimitPreservesPinnedEntries() {
        let store = HistoryStore(fileURL: nil)
        let pinned = entry("오래된 고정", pinned: true)
        store.add(pinned)
        for number in 0..<120 { store.add(entry("기록 \(number)")) }
        XCTAssertEqual(store.entries.count, HistoryStore.maxItems)
        XCTAssertTrue(store.entries.contains { $0.id == pinned.id })
        XCTAssertFalse(store.entries.contains { $0.text == "기록 0" })
        XCTAssertEqual(store.filtered(query: "", filter: .all).first?.id, pinned.id)
    }

    func testPinLimitAndClear() {
        let store = HistoryStore(fileURL: nil)
        for number in 0..<21 {
            let value = entry("\(number)")
            store.add(value)
            XCTAssertEqual(store.togglePin(value.id), number < 20)
        }
        store.clear()
        XCTAssertEqual(store.entries.count, 20)
        store.clear(includingPinned: true)
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testSearchAndFilters() {
        let store = HistoryStore(fileURL: nil)
        store.add(entry("한글 검색 확인"))
        store.add(entry("https://example.com", pinned: true))
        store.add(ClipboardEntry(text: "이미지", isImage: true, source: "Preview", representations: [
            .init(type: NSPasteboard.PasteboardType.png.rawValue, data: Data([1, 2, 3]))
        ]))
        XCTAssertEqual(store.filtered(query: " 한글 ", filter: .all).count, 1)
        XCTAssertEqual(store.filtered(query: "테스트", filter: .text).count, 2)
        XCTAssertEqual(store.filtered(query: "", filter: .images).count, 1)
        XCTAssertEqual(store.filtered(query: "example", filter: .pinned).count, 1)
        XCTAssertEqual(store.filtered(query: "no matches", filter: .all).count, 0)
    }

    func testPersistenceRoundTripAndDisableErasesFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: url)
        store.add(entry("다시 실행해도 남는 기록", pinned: true))
        store.flush()
        let loaded = HistoryStore(fileURL: url)
        XCTAssertEqual(loaded.entries, store.entries)
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o600)
        store.persistenceEnabled = false
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        store.add(entry("메모리에만 저장"))
        store.flush()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(store.entries.count, 2)
    }

    func testCorruptArchiveDoesNotCrash() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("broken data".utf8).write(to: url)
        let store = HistoryStore(fileURL: url)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertNotNil(store.persistenceError)
    }

    func testOversizedItemsAreRejected() {
        let store = HistoryStore(fileURL: nil)
        store.add(ClipboardEntry(text: "큰 데이터", representations: [
            .init(type: "public.utf8-plain-text", data: Data(count: HistoryStore.maxItemBytes + 1))
        ]))
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testSensitivePasteboardsAreNotCaptured() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        for ignored in ClipboardReader.ignoredTypes {
            pasteboard.clearContents()
            let item = NSPasteboardItem()
            item.setString("synthetic-secret", forType: .string)
            item.setData(Data(), forType: .init(ignored))
            XCTAssertTrue(pasteboard.writeObjects([item]))
            XCTAssertNil(ClipboardReader.read(pasteboard, source: "test"), ignored)
        }
    }

    func testTextFormattingRoundTripAndPlainTextRestore() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("한글과 emoji 🎉", forType: .string)
        item.setString("<b>한글과 emoji 🎉</b>", forType: .html)
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([item]))
        let captured = try XCTUnwrap(ClipboardReader.read(pasteboard, source: "test"))
        XCTAssertFalse(captured.isImage)
        XCTAssertEqual(captured.representations.count, 2)
        XCTAssertTrue(ClipboardReader.write(captured, to: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .html), "<b>한글과 emoji 🎉</b>")
        XCTAssertTrue(ClipboardReader.write(captured, to: pasteboard, plainText: true))
        XCTAssertEqual(pasteboard.string(forType: .string), "한글과 emoji 🎉")
        XCTAssertNil(pasteboard.string(forType: .html))
    }

    func testImageRoundTrip() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let png = bitmap.representation(using: .png, properties: [:])!
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        XCTAssertTrue(pasteboard.writeObjects([item]))
        let captured = try XCTUnwrap(ClipboardReader.read(pasteboard, source: "test"))
        XCTAssertTrue(captured.isImage)
        XCTAssertNotNil(captured.image)
        XCTAssertTrue(ClipboardReader.write(captured, to: pasteboard))
        XCTAssertEqual(pasteboard.data(forType: .png), png)
    }

    func testFileCopiesAndBlankTextAreIgnored() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("file:///tmp/example.txt", forType: .fileURL)
        item.setString("/tmp/example.txt", forType: .string)
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([item]))
        XCTAssertNil(ClipboardReader.read(pasteboard, source: "Finder"))
        pasteboard.clearContents()
        pasteboard.setString(" \n\t", forType: .string)
        XCTAssertNil(ClipboardReader.read(pasteboard, source: "test"))
    }

    func testMonitorPauseAndOwnWrites() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let store = HistoryStore(fileURL: nil)
        let monitor = ClipboardMonitor(store: store, pasteboard: pasteboard)
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setString("첫 번째", forType: .string))
        monitor.poll()
        XCTAssertEqual(store.entries.count, 1)
        monitor.isPaused = true
        pasteboard.clearContents()
        pasteboard.setString("기록되면 안 됨", forType: .string)
        monitor.poll()
        monitor.isPaused = false
        monitor.poll()
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertTrue(monitor.restore(entry("내가 쓴 복사")))
        monitor.poll()
        XCTAssertEqual(store.entries.count, 1)
        pasteboard.clearContents()
        pasteboard.setString("두 번째", forType: .string)
        monitor.poll()
        XCTAssertEqual(store.entries.count, 2)
    }
}
