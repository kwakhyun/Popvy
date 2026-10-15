import Foundation
#if !APP_STORE
import ApplicationServices
#endif

enum Distribution {
    static let appIdentifiers = ["app.popvy.mac", "app.popvy.mac.store", LegacyMigration.legacyIdentifier]

    #if APP_STORE
    static let isAppStore = true
    static var accessibilityTrusted: Bool { false }
    #else
    static let isAppStore = false
    static var accessibilityTrusted: Bool { AXIsProcessTrusted() }
    #endif

    static var selectionVerb: String { isAppStore ? "복사" : "붙여넣기" }
}
