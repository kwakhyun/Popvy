import Carbon

enum Shortcut: String, CaseIterable, Identifiable {
    case optionV, controlShiftV, commandShiftV
    var id: String { rawValue }
    var label: String {
        switch self {
        case .optionV: return "⌥ V"
        case .controlShiftV: return "⌃ ⇧ V"
        case .commandShiftV: return "⌘ ⇧ V"
        }
    }
    var title: String {
        switch self {
        case .optionV: return "Option + V"
        case .controlShiftV: return "Control + Shift + V"
        case .commandShiftV: return "Command + Shift + V"
        }
    }
    var modifiers: UInt32 {
        switch self {
        case .optionV: return UInt32(optionKey)
        case .controlShiftV: return UInt32(controlKey | shiftKey)
        case .commandShiftV: return UInt32(cmdKey | shiftKey)
        }
    }
}

final class GlobalHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?

    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
            guard let pointer else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<GlobalHotKey>.fromOpaque(pointer).takeUnretainedValue()
            manager.onPress?()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    @discardableResult
    func register(_ shortcut: Shortcut) -> Bool {
        // Register the replacement first so a conflict does not discard the working shortcut.
        var replacement: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: 0x43534846, id: 1)
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_V), shortcut.modifiers, identifier,
                                        GetApplicationEventTarget(), 0, &replacement)
        guard status == noErr else { return false }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = replacement
        return true
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
