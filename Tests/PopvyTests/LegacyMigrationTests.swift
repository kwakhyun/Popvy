import Foundation
import XCTest
@testable import Popvy

final class LegacyMigrationTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        suite = "app.popvy.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
        try FileManager.default.removeItem(at: root)
    }

    private func makeLegacy() throws -> URL {
        let source = LegacyMigration.legacyHistory(in: root)
        try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("test history".utf8).write(to: source)
        return source
    }

    func testMovesHistoryAndImportsPreferencesOnce() throws {
        let source = try makeLegacy()
        let destination = try LegacyMigration.migrate(defaults: defaults,
            legacy: ["autoPaste": false, "shortcut": "custom", "unrelated": true], root: root)
        XCTAssertEqual(try Data(contentsOf: destination), Data("test history".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(defaults.bool(forKey: "autoPaste"))
        XCTAssertEqual(defaults.string(forKey: "shortcut"), "custom")
        XCTAssertNil(defaults.object(forKey: "unrelated"))
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: destination.path)[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        try FileManager.default.removeItem(at: destination)
        _ = try makeLegacy()
        _ = try LegacyMigration.migrate(defaults: defaults, legacy: ["autoPaste": true], root: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(defaults.bool(forKey: "autoPaste"))
    }

    func testExistingPopvyDataAndPreferencesWin() throws {
        _ = try makeLegacy()
        let destination = root.appendingPathComponent("Popvy/history.json")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("new history".utf8).write(to: destination)
        defaults.set(false, forKey: "autoPaste")
        _ = try LegacyMigration.migrate(defaults: defaults, legacy: ["autoPaste": true], root: root)
        XCTAssertEqual(try Data(contentsOf: destination), Data("new history".utf8))
        XCTAssertFalse(defaults.bool(forKey: "autoPaste"))
    }

    func testDisabledPersistenceDoesNotImportHistoryLater() throws {
        _ = try makeLegacy()
        let destination = try LegacyMigration.migrate(defaults: defaults, legacy: ["keepHistory": false], root: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        defaults.set(true, forKey: "keepHistory")
        _ = try LegacyMigration.migrate(defaults: defaults, legacy: [:], root: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testFailedMovePreservesOriginalAndCanRetry() throws {
        let source = try makeLegacy()
        let obstruction = root.appendingPathComponent("Popvy")
        try Data("not a directory".utf8).write(to: obstruction)
        XCTAssertThrowsError(try LegacyMigration.migrate(defaults: defaults, legacy: [:], root: root))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(defaults.bool(forKey: LegacyMigration.completedKey))
        try FileManager.default.removeItem(at: obstruction)
        let destination = try LegacyMigration.migrate(defaults: defaults, legacy: [:], root: root)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }
}
