import AppKit
import Carbon

final class ShortcutRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var keyCode: UInt32 = HotKeyPreference.keyCode
    @Published var modifiers: UInt32 = HotKeyPreference.modifiers
    @Published var errorMessage: String?

    var onChange: ((UInt32, UInt32) -> Void)?

    private var monitor: Any?

    var displayString: String {
        HotKeyPreference.displayString(keyCode: keyCode, modifiers: modifiers)
    }

    func startRecording() {
        errorMessage = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, event.type == .keyDown else { return event }
            self.handle(event)
            return nil // swallow the event while recording
        }
    }

    func cancelRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 {
            errorMessage = nil
            cancelRecording()
            return
        }
        var carbonModifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }

        guard carbonModifiers != 0 else {
            errorMessage = "Shortcut must include at least one modifier key (⌘ ⇧ ⌥ ⌃)."
            return
        }

        let newKeyCode = UInt32(event.keyCode)
        keyCode = newKeyCode
        modifiers = carbonModifiers
        cancelRecording()

        HotKeyPreference.set(keyCode: newKeyCode, modifiers: carbonModifiers)
        onChange?(newKeyCode, carbonModifiers)
    }

    func resetToDefault() {
        cancelRecording()
        errorMessage = nil
        keyCode = HotKeyPreference.defaultKeyCode
        modifiers = HotKeyPreference.defaultModifiers
        HotKeyPreference.set(keyCode: keyCode, modifiers: modifiers)
        onChange?(keyCode, modifiers)
    }
}
