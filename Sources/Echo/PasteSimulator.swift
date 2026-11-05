import AppKit

/// Synthesizes a Cmd+V key event into whatever app is frontmost.
/// Requires the app to be granted Accessibility permission
/// (System Settings > Privacy & Security > Accessibility).
enum PasteSimulator {
    /// Wait for the destination to actually regain focus before injecting paste.
    /// A fixed delay can send the event back to Echo on slower app switches.
    static func pasteWhenActive(_ target: NSRunningApplication, attemptsRemaining: Int = 20) {
        guard !target.isTerminated, attemptsRemaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier {
                sendCommandV()
            } else {
                pasteWhenActive(target, attemptsRemaining: attemptsRemaining - 1)
            }
        }
    }

    static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 9 // kVK_ANSI_V

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    static var hasAccessibilityPermission: Bool {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Prompts the system Accessibility permission dialog if not already granted.
    static func requestAccessibilityPermissionIfNeeded() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
