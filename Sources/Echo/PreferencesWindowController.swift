import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    convenience init(recorder: ShortcutRecorder) {
        let hosting = NSHostingController(rootView: PreferencesView(recorder: recorder))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Echo Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.contentMinSize = NSSize(width: 420, height: 440)
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
