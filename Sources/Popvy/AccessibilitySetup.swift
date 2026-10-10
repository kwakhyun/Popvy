import Combine
import Foundation

final class AccessibilitySetup: ObservableObject {
    static let completedKey = "didFinishAccessibilitySetup"
    @Published private(set) var isTrusted: Bool
    @Published private(set) var isWaiting = false
    private let defaults: UserDefaults

    init(defaults: UserDefaults, isTrusted: Bool) {
        self.defaults = defaults
        self.isTrusted = isTrusted
    }

    var shouldPresentOnLaunch: Bool { !isTrusted && !defaults.bool(forKey: Self.completedKey) }

    func beginRequest() { isWaiting = !isTrusted }

    /// Only an explicit request enables auto-paste; background permission changes preserve preferences.
    @discardableResult
    func updateTrust(_ trusted: Bool) -> Bool {
        if isTrusted != trusted { isTrusted = trusted }
        guard trusted && isWaiting else { return false }
        isWaiting = false
        defaults.set(true, forKey: Self.completedKey)
        return true
    }

    func finish() {
        isWaiting = false
        defaults.set(true, forKey: Self.completedKey)
    }
}
