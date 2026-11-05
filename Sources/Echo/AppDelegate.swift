import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: HistoryStore!
    private var monitor: ClipboardMonitor!
    private var statusBarController: StatusBarController!
    private var hotKeyManager: HotKeyManager!
    private var shortcutRecorder: ShortcutRecorder!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu-bar only, no Dock icon

        store = HistoryStore()
        monitor = ClipboardMonitor(store: store)
        monitor.start()

        shortcutRecorder = ShortcutRecorder()
        statusBarController = StatusBarController(store: store, monitor: monitor, shortcutRecorder: shortcutRecorder)

        hotKeyManager = HotKeyManager { [weak self] in
            self?.statusBarController.toggle()
        }
        hotKeyManager.register(keyCode: HotKeyPreference.keyCode, modifiers: HotKeyPreference.modifiers)

        shortcutRecorder.onChange = { [weak self] keyCode, modifiers in
            self?.hotKeyManager.update(keyCode: keyCode, modifiers: modifiers)
        }

        if !PasteSimulator.hasAccessibilityPermission {
            PasteSimulator.requestAccessibilityPermissionIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        hotKeyManager.unregister()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
