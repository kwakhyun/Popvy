import AppKit
#if !APP_STORE
import ApplicationServices
#endif

enum PopupPlacement {
    static let width: CGFloat = 336
    static let rowHeight: CGFloat = 76

    static func size(itemCount: Int, searching: Bool, hasNotice: Bool) -> NSSize {
        let rows = CGFloat(min(max(itemCount, 0), 4))
        let list = rows == 0 ? 112 : rows * rowHeight + max(0, rows - 1) * 6 + 16
        return NSSize(width: width, height: 44 + list + 30 + (searching ? 42 : 0) + (hasNotice ? 56 : 0))
    }

    /// AppKit screen coordinates (origin at the bottom left), including negative monitor origins.
    static func frame(anchor: NSRect, size: NSSize, visibleFrame: NSRect) -> NSRect {
        let area = visibleFrame.insetBy(dx: 8, dy: 8)
        let width = min(size.width, area.width)
        let height = min(size.height, area.height)
        let below = anchor.minY - 8 - height
        let above = anchor.maxY + 8
        let preferredY = below >= area.minY ? below : above
        return NSRect(x: min(max(anchor.minX, area.minX), area.maxX - width),
                      y: min(max(preferredY, area.minY), area.maxY - height), width: width, height: height)
    }

    static func appKitRect(fromAccessibility rect: CGRect, primaryScreen: NSRect) -> NSRect {
        NSRect(x: rect.minX, y: primaryScreen.maxY - rect.maxY, width: max(1, rect.width), height: rect.height)
    }
}

#if !APP_STORE
/// Remembers the input control before showing the popup. Never reads the user's text.
struct PasteFocus {
    let application: AXUIElement
    let element: AXUIElement
    let selectedRange: AXValue?

    static func capture(pid: pid_t) -> PasteFocus? {
        guard AXIsProcessTrusted() else { return nil }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.15)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = unsafeBitCast(focused, to: AXUIElement.self)
        AXUIElementSetMessagingTimeout(element, 0.15)
        var range: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range)
        let value = range.flatMap { CFGetTypeID($0) == AXValueGetTypeID() ? unsafeBitCast($0, to: AXValue.self) : nil }
        return PasteFocus(application: application, element: element, selectedRange: value)
    }

    func caretRect() -> NSRect? {
        guard let selectedRange, AXValueGetType(selectedRange) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(selectedRange, .cfRange, &range), range.location >= 0,
              range.length >= 0, range.location <= Int.max - range.length else { return nil }
        range.location += range.length
        range.length = 0
        guard let insertionRange = AXValueCreate(.cfRange, &range) else { return nil }
        var bounds: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString,
                insertionRange, &bounds) == .success,
              let bounds, CFGetTypeID(bounds) == AXValueGetTypeID() else { return nil }
        let value = unsafeBitCast(bounds, to: AXValue.self)
        var rect = CGRect.zero
        guard AXValueGetType(value) == .cgRect, AXValueGetValue(value, .cgRect, &rect),
              rect.origin.x.isFinite, rect.origin.y.isFinite, rect.width.isFinite,
              rect.height.isFinite, rect.height > 0, rect.height < 200,
              let primary = NSScreen.screens.first else { return nil }
        let result = PopupPlacement.appKitRect(fromAccessibility: rect, primaryScreen: primary.frame)
        guard NSScreen.screens.contains(where: { $0.visibleFrame.intersects(result) }) else { return nil }
        return result
    }

    func restoreIfNeeded() -> Bool {
        var current: CFTypeRef?
        if AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &current) == .success,
           let current, CFEqual(current, element) { return true }
        // A nonactivating panel normally preserves focus. Recover it only if another control took it.
        guard AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success else { return false }
        if let selectedRange {
            guard AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, selectedRange) == .success else { return false }
        }
        return true
    }
}

#endif
