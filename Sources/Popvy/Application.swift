import AppKit
import ApplicationServices
import Carbon
import Combine
import ServiceManagement
import SwiftUI

final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    let store: HistoryStore
    let monitor: ClipboardMonitor
    let isDemo: Bool
    let accessibilitySetup: AccessibilitySetup
    @Published var accessibilitySetupError: String?
    @Published var query = "" { didSet { reconcileSelection() } }
    @Published var filter: HistoryFilter = .all { didSet { reconcileSelection() } }
    @Published var isSearchVisible = false { didSet { updatePanelFrame() } }
    @Published var selectedID: UUID?
    @Published var shortcut: Shortcut
    @Published var accessibilityGranted = AXIsProcessTrusted()
    @Published var autoPaste: Bool { didSet { defaults.set(autoPaste, forKey: "autoPaste") } }
    @Published var keepHistory: Bool {
        didSet {
            defaults.set(keepHistory, forKey: "keepHistory")
            store.persistenceEnabled = keepHistory
        }
    }
    @Published var launchAtLogin = false
    @Published var notice: String? { didSet { updatePanelFrame() } }
    @Published var showCopied = false
    private let defaults: UserDefaults
    private let hotKey = GlobalHotKey()
    private var statusItem: NSStatusItem!
    private var panel: ClipboardPanel!
    private var settingsWindow: NSWindow?
    private var accessibilityWindow: NSWindow?
    private var targetApplication: NSRunningApplication?
    private var pasteFocus: PasteFocus?
    private var popupAnchor = NSRect.zero
    private var popupScreenFrame = NSRect.zero
    private var workspaceObserver: NSObjectProtocol?
    private var localMonitor: Any?
    private var outsideMonitor: Any?
    private var subscriptions = Set<AnyCancellable>()
    private var trustTimer: Timer?
    private var isPasting = false

    var visibleEntries: [ClipboardEntry] { store.filtered(query: query, filter: filter) }
    var canAutoPaste: Bool { autoPaste && accessibilityGranted }

    override init() {
        isDemo = CommandLine.arguments.contains("--demo")
        let defaults = isDemo ? UserDefaults(suiteName: "app.popvy.demo")! : .standard
        self.defaults = defaults
        accessibilitySetup = AccessibilitySetup(defaults: defaults, isTrusted: AXIsProcessTrusted())
        let identifiers = [LegacyMigration.legacyIdentifier, "app.popvy.mac"]
        let anotherInstanceRunning = identifiers.contains { identifier in
            NSRunningApplication.runningApplications(withBundleIdentifier: identifier).contains {
                $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }
        }
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var historyURL = root.appendingPathComponent("Popvy/history.json")
        var migrationNotice: String?
        if !isDemo, !anotherInstanceRunning {
            do {
                historyURL = try LegacyMigration.migrate(defaults: defaults,
                    legacy: defaults.persistentDomain(forName: LegacyMigration.legacyIdentifier) ?? [:], root: root)
            } catch {
                historyURL = LegacyMigration.legacyHistory(in: root)
                migrationNotice = "기록 위치를 옮기지 못해 이전 저장 위치를 사용합니다. 다음 실행 때 다시 시도합니다."
            }
        }
        defaults.register(defaults: ["autoPaste": true, "keepHistory": true, "shortcut": Shortcut.optionV.rawValue])
        autoPaste = defaults.bool(forKey: "autoPaste")
        let shouldKeepHistory = defaults.bool(forKey: "keepHistory")
        keepHistory = shouldKeepHistory
        shortcut = Shortcut(rawValue: defaults.string(forKey: "shortcut") ?? "") ?? .optionV
        store = HistoryStore(fileURL: isDemo || anotherInstanceRunning ? nil : historyURL, persistenceEnabled: shouldKeepHistory)
        monitor = ClipboardMonitor(store: store)
        super.init()
        notice = migrationNotice
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !isDemo, !NSRunningApplication.runningApplications(withBundleIdentifier: LegacyMigration.legacyIdentifier).isEmpty {
            let alert = NSAlert()
            alert.messageText = "이전 버전을 종료해 주세요"
            alert.informativeText = "기록과 단축키가 충돌하지 않도록 이전 클립보드 앱을 종료한 뒤 Popvy를 다시 실행해 주세요."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        // Keep a single menu-bar process even if the app is opened twice.
        if !isDemo, let identifier = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: identifier).contains(where: {
               $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
           }) {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        createMenuBarItem()
        createPanel()
        hotKey.onPress = { [weak self] in self?.togglePanel() }
        if !hotKey.register(shortcut) {
            notice = "\(shortcut.title) 단축키를 등록하지 못했습니다. 설정에서 다른 키를 선택해 주세요."
        }
        installKeyHandling()
        store.$entries.receive(on: RunLoop.main).sink { [weak self] _ in self?.reconcileSelection() }.store(in: &subscriptions)
        store.$persistenceError.receive(on: RunLoop.main).sink { [weak self] _ in self?.updatePanelFrame() }.store(in: &subscriptions)
        monitor.$clipboardAccessDenied.receive(on: RunLoop.main).sink { [weak self] _ in self?.updatePanelFrame() }.store(in: &subscriptions)
        monitor.$isPaused.receive(on: RunLoop.main).sink { [weak self] paused in
            self?.statusItem.button?.image = NSImage(systemSymbolName: paused ? "pause.rectangle" : "clipboard", accessibilityDescription: "Popvy")
        }.store(in: &subscriptions)
        launchAtLogin = SMAppService.mainApp.status == .enabled
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshAccessibility()
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self, self.panel.isVisible,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != self.targetApplication?.processIdentifier,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            self.hidePanel()
        }
        if isDemo { loadDemo() }
        else { monitor.start() }
        if !isDemo && accessibilitySetup.shouldPresentOnLaunch {
            defaults.set(true, forKey: "hasLaunched")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.showAccessibilitySetup() }
        } else if isDemo || !defaults.bool(forKey: "hasLaunched") {
            defaults.set(true, forKey: "hasLaunched")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.showPanel() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.flush()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
        trustTimer?.invalidate()
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if accessibilityWindow?.isVisible == true { showAccessibilitySetup() }
        else { showPanel() }
        return true
    }

    private func createMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Popvy 클립보드 기록")
            button.toolTip = "Popvy — \(shortcut.title)"
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        let menu = NSMenu()
        let appMenu = NSMenuItem()
        let submenu = NSMenu()
        submenu.addItem(withTitle: "Popvy 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.submenu = submenu
        menu.addItem(appMenu)
        let edit = NSMenuItem(title: "편집", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "편집")
        editMenu.addItem(withTitle: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "잘라내기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "전체 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.submenu = editMenu
        menu.addItem(edit)
        NSApp.mainMenu = menu
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "기록 열기  \(shortcut.label)", action: #selector(openHistory), keyEquivalent: "")
            menu.addItem(withTitle: monitor.isPaused ? "기록 다시 시작" : "기록 일시 정지", action: #selector(togglePause), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "설정…", action: #selector(openSettings), keyEquivalent: "")
            menu.addItem(withTitle: "Popvy 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            for item in menu.items where !item.isSeparatorItem { item.target = item.action == #selector(NSApplication.terminate(_:)) ? NSApp : self }
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else { togglePanel() }
    }

    @objc private func openHistory() { showPanel() }
    @objc func togglePause() { monitor.isPaused.toggle() }

    private func createPanel() {
        panel = ClipboardPanel(contentRect: NSRect(x: 0, y: 0, width: PopupPlacement.width, height: 260),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Popvy"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: HistoryView(app: self, store: store, monitor: monitor))
    }

    func togglePanel() {
        if accessibilityWindow?.isVisible == true { showAccessibilitySetup(); return }
        if panel.isVisible && panel.isKeyWindow { hidePanel(restoreFocus: true) }
        else { showPanel() }
    }

    func showPanel() {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            targetApplication = frontmost
        }
        accessibilityGranted = AXIsProcessTrusted()
        pasteFocus = targetApplication.flatMap { PasteFocus.capture(pid: $0.processIdentifier) }
        let pointer = NSEvent.mouseLocation
        popupAnchor = pasteFocus?.caretRect() ?? NSRect(origin: pointer, size: NSSize(width: 1, height: 1))
        let anchorPoint = NSPoint(x: popupAnchor.midX, y: popupAnchor.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(anchorPoint) }
            ?? NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        popupScreenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        isSearchVisible = false
        query = ""
        filter = .all
        showCopied = false
        selectedID = visibleEntries.first?.id
        updatePanelFrame()
        // Keep the original app active and its insertion point intact, even while searching.
        panel.makeKeyAndOrderFront(nil)
    }

    private func updatePanelFrame() {
        guard panel != nil, !popupScreenFrame.isEmpty else { return }
        let size = PopupPlacement.size(itemCount: visibleEntries.count, searching: isSearchVisible,
            hasNotice: notice != nil || store.persistenceError != nil || monitor.clipboardAccessDenied)
        panel.setFrame(PopupPlacement.frame(anchor: popupAnchor, size: size, visibleFrame: popupScreenFrame), display: true)
    }

    func toggleSearch() {
        isSearchVisible.toggle()
        if isSearchVisible {
            DispatchQueue.main.async { NotificationCenter.default.post(name: .focusPopvySearch, object: nil) }
        } else { query = "" }
    }

    func hidePanel(restoreFocus: Bool = false) {
        showCopied = false
        panel.orderOut(nil)
        if restoreFocus, let targetApplication, !targetApplication.isTerminated {
            targetApplication.activate(options: [])
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        if notification.object as? NSWindow === panel { panel.orderOut(nil) }
    }

    func reconcileSelection() {
        let entries = visibleEntries
        if !entries.contains(where: { $0.id == selectedID }) { selectedID = entries.first?.id }
        updatePanelFrame()
    }

    func moveSelection(_ delta: Int) {
        let entries = visibleEntries
        guard !entries.isEmpty else { return }
        let current = entries.firstIndex { $0.id == selectedID } ?? 0
        selectedID = entries[min(max(0, current + delta), entries.count - 1)].id
    }

    private func installKeyHandling() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            // Enter and arrows must finish Korean/Japanese composition before navigating history.
            if let editor = self.panel.firstResponder as? NSTextView, editor.hasMarkedText() { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            switch Int(event.keyCode) {
            case kVK_ANSI_F where flags.contains(.command):
                if !self.isSearchVisible { self.toggleSearch() }
                else { NotificationCenter.default.post(name: .focusPopvySearch, object: nil) }
                return nil
            case kVK_Escape:
                self.hidePanel(restoreFocus: true); return nil
            case kVK_DownArrow where flags.isDisjoint(with: [.command, .option, .control]):
                self.moveSelection(1); return nil
            case kVK_UpArrow where flags.isDisjoint(with: [.command, .option, .control]):
                self.moveSelection(-1); return nil
            case kVK_Return, kVK_ANSI_KeypadEnter:
                if let id = self.selectedID, let entry = self.store.entries.first(where: { $0.id == id }) {
                    self.use(entry, copyOnly: flags.contains(.shift), plainText: flags.contains(.command))
                }
                return nil
            default:
                if flags.contains(.command), let number = Int(event.charactersIgnoringModifiers ?? ""), (1...9).contains(number) {
                    let entries = self.visibleEntries
                    if entries.count >= number { self.use(entries[number - 1]) }
                    return nil
                }
                return event
            }
        }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
    }

    func use(_ entry: ClipboardEntry, copyOnly: Bool = false, plainText: Bool = false) {
        guard !isPasting else { return }
        guard monitor.restore(entry, plainText: plainText) else {
            notice = "클립보드에 복사하지 못했습니다. 다시 시도해 주세요."
            return
        }
        accessibilityGranted = AXIsProcessTrusted()
        guard !copyOnly, canAutoPaste, let target = targetApplication, !target.isTerminated,
              target.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            showCopied = true
            // Keep a visible confirmation so permission-free mode is never a silent no-op.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
                guard let self, self.showCopied else { return }
                self.hidePanel(restoreFocus: true)
                self.showCopied = false
            }
            return
        }
        isPasting = true
        let focus = pasteFocus
        hidePanel()
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != target.processIdentifier {
            target.activate(options: [])
        }
        finishPaste(to: target, focus: focus, attempt: 0)
    }

    private func finishPaste(to target: NSRunningApplication, focus: PasteFocus?, attempt: Int) {
        // Wait for activation and released shortcut modifiers. Never type into a different app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let held = CGEventSource.flagsState(.combinedSessionState).intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
            guard front == target.processIdentifier, held.isEmpty else {
                if attempt < 12 { self.finishPaste(to: target, focus: focus, attempt: attempt + 1) }
                else { self.isPasting = false; self.notifyCopiedFallback() }
                return
            }
            guard AXIsProcessTrusted(), focus?.restoreIfNeeded() != false,
                  let source = CGEventSource(stateID: .privateState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
                self.isPasting = false
                self.notifyCopiedFallback()
                return
            }
            down.flags = .maskCommand
            up.flags = .maskCommand
            // Route both events to the app that owned the input cursor, never to the popup.
            down.postToPid(target.processIdentifier)
            up.postToPid(target.processIdentifier)
            self.isPasting = false
        }
    }

    private func notifyCopiedFallback() {
        notice = "복사했습니다. 붙여넣을 곳에서 ⌘ V를 눌러 주세요."
        showPanel()
    }

    func pin(_ entry: ClipboardEntry) {
        if !store.togglePin(entry.id) { notice = "고정은 최대 20개까지 가능합니다." }
    }

    func changeShortcut(_ newValue: Shortcut) {
        guard newValue != shortcut else { return }
        if hotKey.register(newValue) {
            shortcut = newValue
            defaults.set(newValue.rawValue, forKey: "shortcut")
            statusItem.button?.toolTip = "Popvy — \(newValue.title)"
            notice = nil
        } else { notice = "다른 앱이 \(newValue.title)를 사용하고 있습니다. 다른 단축키를 선택해 주세요." }
    }

    func requestAccessibility() {
        showAccessibilitySetup()
    }

    func showAccessibilitySetup() {
        hidePanel()
        refreshAccessibility()
        if accessibilityGranted { autoPaste = true }
        accessibilitySetupError = nil
        if accessibilityWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 490, height: 520),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Popvy 시작하기"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: PermissionSetupView(app: self, setup: accessibilitySetup))
            accessibilityWindow = window
        }
        accessibilityWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        accessibilityWindow?.makeKeyAndOrderFront(nil)
    }

    func openAccessibilitySettings() {
        accessibilitySetupError = nil
        refreshAccessibility()
        accessibilitySetup.beginRequest()
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshAccessibility()
        if accessibilityGranted { autoPaste = true; return }
        if !accessibilityGranted,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            if !NSWorkspace.shared.open(url) {
                accessibilitySetupError = "설정을 열지 못했습니다. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용으로 이동해 주세요."
            }
        }
    }

    private func refreshAccessibility() {
        let trusted = AXIsProcessTrusted()
        if accessibilityGranted != trusted { accessibilityGranted = trusted }
        if accessibilitySetup.updateTrust(trusted) {
            autoPaste = true
            accessibilitySetupError = nil
            // Update the open guide without pulling focus away from System Settings.
            if accessibilityWindow?.isVisible == true { accessibilityWindow?.orderFront(nil) }
        }
    }

    func finishAccessibilitySetup() {
        if accessibilityGranted { autoPaste = true }
        accessibilitySetup.finish()
        accessibilityWindow?.close()
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === accessibilityWindow { accessibilitySetup.finish() }
    }

    func setLaunchAtLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                notice = "시스템 설정의 로그인 항목에서 Popvy를 허용해 주세요."
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            notice = "로그인 실행을 변경하지 못했습니다. 앱을 응용 프로그램 폴더에 설치한 뒤 다시 시도해 주세요."
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func confirmClear(includingPinned: Bool) {
        let alert = NSAlert()
        alert.messageText = includingPinned ? "모든 기록을 삭제할까요?" : "고정하지 않은 기록을 삭제할까요?"
        alert.informativeText = includingPinned ? "고정한 항목까지 삭제합니다. 이 작업은 되돌릴 수 없습니다." : "고정한 항목은 남겨 둡니다. 이 작업은 되돌릴 수 없습니다."
        alert.addButton(withTitle: "삭제")
        alert.addButton(withTitle: "취소")
        if alert.runModal() == .alertFirstButtonReturn { store.clear(includingPinned: includingPinned) }
    }

    @objc func openSettings() {
        hidePanel()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 510, height: 560),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Popvy 설정"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(app: self, store: store))
            settingsWindow = window
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        settingsWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func loadDemo() {
        let samples: [(String, String)] = [
            ("작은 아이디어도 놓치지 않도록.\n복사한 순간부터 다시 필요해질 때까지.", "메모"),
            ("https://developer.apple.com/design/", "Safari"),
            ("이번 주에 할 일\n기획안 검토하기\n팀 회의 준비하기\n새로운 아이디어 기록하기", "메모"),
            ("안녕하세요. 보내주신 내용 확인했습니다.\n검토 후 내일까지 답변드리겠습니다.", "Mail")
        ]
        for (offset, sample) in samples.enumerated() {
            let entry = ClipboardEntry(text: sample.0, source: sample.1,
                representations: [.init(type: NSPasteboard.PasteboardType.string.rawValue, data: Data(sample.0.utf8))],
                createdAt: Date().addingTimeInterval(Double(-offset * 180)), isPinned: offset == 0)
            store.add(entry)
        }
    }
}

extension Notification.Name {
    static let focusPopvySearch = Notification.Name("focusPopvySearch")
}
