import Carbon
import AppKit

/// Registers a single global hotkey (default: Cmd+Shift+V) using the Carbon
/// Hot Key API, which is still the standard way to get a system-wide shortcut
/// without needing an Accessibility-permission event tap.
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let onTrigger: () -> Void

    private static let signature: OSType = {
        let s = "Echo"
        var result: OSType = 0
        for scalar in s.unicodeScalars {
            result = (result << 8) + OSType(scalar.value)
        }
        return result
    }()
    private static let hotKeyID = UInt32(1)

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    private var isHandlerInstalled = false

    func register(keyCode: UInt32 = HotKeyPreference.defaultKeyCode, modifiers: UInt32 = HotKeyPreference.defaultModifiers) {
        if !isHandlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, userData in
                guard let userData, let eventRef else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                var hkID = EventHotKeyID()
                GetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                if hkID.id == HotKeyManager.hotKeyID {
                    DispatchQueue.main.async { manager.onTrigger() }
                }
                return noErr
            }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
            isHandlerInstalled = true
        }

        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        let id = EventHotKeyID(signature: HotKeyManager.signature, id: HotKeyManager.hotKeyID)
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    /// Swaps the active shortcut for a new key/modifier combo without tearing down the event handler.
    func update(keyCode: UInt32, modifiers: UInt32) {
        register(keyCode: keyCode, modifiers: modifiers)
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
            isHandlerInstalled = false
        }
    }

    deinit {
        unregister()
    }
}
