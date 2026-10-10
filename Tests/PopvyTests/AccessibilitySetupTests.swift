import XCTest
@testable import Popvy

final class AccessibilitySetupTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        suite = "app.popvy.setup-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    func testFirstLaunchAndExistingUsersSeeGuideWithoutPermission() {
        defaults.set(true, forKey: "hasLaunched")
        XCTAssertTrue(AccessibilitySetup(defaults: defaults, isTrusted: false).shouldPresentOnLaunch)
        XCTAssertFalse(AccessibilitySetup(defaults: defaults, isTrusted: true).shouldPresentOnLaunch)
    }

    func testSkippingPersistsAndCancelsPendingRequest() {
        let setup = AccessibilitySetup(defaults: defaults, isTrusted: false)
        setup.beginRequest()
        setup.finish()
        XCTAssertFalse(setup.isWaiting)
        XCTAssertFalse(setup.updateTrust(true))
        XCTAssertFalse(AccessibilitySetup(defaults: defaults, isTrusted: false).shouldPresentOnLaunch)
    }

    func testGrantAfterRequestEnablesAutoPasteExactlyOnce() {
        let setup = AccessibilitySetup(defaults: defaults, isTrusted: false)
        setup.beginRequest()
        XCTAssertTrue(setup.isWaiting)
        XCTAssertFalse(setup.updateTrust(false))
        XCTAssertTrue(setup.isWaiting)
        XCTAssertTrue(setup.updateTrust(true))
        XCTAssertTrue(setup.isTrusted)
        XCTAssertFalse(setup.isWaiting)
        XCTAssertFalse(setup.shouldPresentOnLaunch)
        XCTAssertFalse(setup.updateTrust(true))
    }

    func testBackgroundGrantDoesNotOverrideAutoPastePreference() {
        let setup = AccessibilitySetup(defaults: defaults, isTrusted: false)
        XCTAssertFalse(setup.updateTrust(true))
        XCTAssertTrue(setup.isTrusted)
    }

    func testPermissionCanBeRevokedAndRequestedAgainAfterCompletion() {
        let setup = AccessibilitySetup(defaults: defaults, isTrusted: true)
        setup.finish()
        XCTAssertFalse(setup.updateTrust(false))
        XCTAssertFalse(setup.isTrusted)
        XCTAssertFalse(setup.shouldPresentOnLaunch)
        setup.beginRequest()
        XCTAssertTrue(setup.updateTrust(true))
    }
}
