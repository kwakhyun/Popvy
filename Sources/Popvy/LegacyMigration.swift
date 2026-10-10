import Foundation

/// These old names are retained only to import installations made before the rename.
enum LegacyMigration {
    static let legacyIdentifier = "app.clipshelf.mac"
    static let completedKey = "didMigrateLegacyStorage"
    static let preferenceKeys = ["autoPaste", "keepHistory", "shortcut", "hasLaunched"]

    static func legacyHistory(in root: URL) -> URL {
        root.appendingPathComponent("ClipShelf/history.json")
    }

    static func migrate(defaults: UserDefaults, legacy: [String: Any], root: URL) throws -> URL {
        let destination = root.appendingPathComponent("Popvy/history.json")
        guard !defaults.bool(forKey: completedKey) else { return destination }
        // Explicit values already chosen in Popvy take precedence over legacy settings.
        for key in preferenceKeys where defaults.object(forKey: key) == nil {
            if let value = legacy[key] { defaults.set(value, forKey: key) }
        }
        let manager = FileManager.default
        let source = legacyHistory(in: root)
        if defaults.object(forKey: "keepHistory") as? Bool != false,
           !manager.fileExists(atPath: destination.path), manager.fileExists(atPath: source.path) {
            let directory = destination.deletingLastPathComponent()
            try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
            try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: source.path)
            // Move instead of leaving a second copy of private clipboard history behind.
            try manager.moveItem(at: source, to: destination)
        }
        defaults.set(true, forKey: completedKey)
        return destination
    }
}
