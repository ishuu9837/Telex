import Carbon

@MainActor protocol GlobalHotkeyServiceProtocol: AnyObject { var onAction: ((UInt32) -> Void)? { get set }; func register() throws; func unregister() }
@MainActor final class GlobalHotkeyService: GlobalHotkeyServiceProtocol {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    var onAction: ((UInt32) -> Void)?
    static let shortcuts: [(UInt32, UInt32, String)] = [
        (UInt32(kVK_Return), UInt32(cmdKey), "⌘ Return · Play / pause"),
        (UInt32(kVK_ANSI_T), UInt32(cmdKey | shiftKey), "⇧⌘T · Show / hide"),
        (UInt32(kVK_ANSI_D), UInt32(cmdKey | shiftKey), "⇧⌘D · Dock / float"),
        (UInt32(kVK_ANSI_L), UInt32(cmdKey | shiftKey), "⇧⌘L · Click-through"),
        (UInt32(kVK_ANSI_R), UInt32(cmdKey | shiftKey), "⇧⌘R · Record"),
        (UInt32(kVK_ANSI_Equal), UInt32(cmdKey | optionKey), "⌥⌘+ · Faster"),
        (UInt32(kVK_ANSI_Minus), UInt32(cmdKey | optionKey), "⌥⌘− · Slower"),
        (UInt32(kVK_RightArrow), UInt32(controlKey | optionKey), "⌃⌥→ · Next cue"),
        (UInt32(kVK_LeftArrow), UInt32(controlKey | optionKey), "⌃⌥← · Previous cue"),
        (UInt32(kVK_ANSI_B), UInt32(controlKey | optionKey), "⌃⌥B · Return to spot"),
        (UInt32(kVK_UpArrow), UInt32(cmdKey | optionKey), "⌥⌘↑ · Scroll up"),
        (UInt32(kVK_DownArrow), UInt32(cmdKey | optionKey), "⌥⌘↓ · Scroll down")
    ]
    func register() throws {
        unregister()
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr else { return status }
            let service = Unmanaged<GlobalHotkeyService>.fromOpaque(context).takeUnretainedValue()
            let actionID = id.id
            MainActor.assumeIsolated { service.onAction?(actionID) }
            return noErr
        }, 1, &type, pointer, &handler)
        guard result == noErr else { throw TelexError.hotkeyConflict("Global keyboard handler") }
        var conflicts: [String] = []
        for (index, binding) in Self.shortcuts.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: 0x544C4558, id: UInt32(index))
            let status = RegisterEventHotKey(binding.0, binding.1, id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs.append(ref) } else { conflicts.append(binding.2) }
        }
        for (index, key) in [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9].enumerated() {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(key), UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x544C4558, id: UInt32(20 + index)), GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs.append(ref) } else { conflicts.append("⌃⌥\(index + 1)") }
        }
        if !conflicts.isEmpty { throw TelexError.hotkeyConflict(conflicts.joined(separator: ", ")) }
    }
    func unregister() {
        refs.forEach { UnregisterEventHotKey($0) }; refs.removeAll()
        if let handler { RemoveEventHandler(handler) }; handler = nil
    }
}
