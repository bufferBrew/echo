import AppKit
import SwiftUI

/// Floating panel used for the history popup. A panel rather than an NSPopover,
/// because the popup has to open at the caret (not anchored to the menu bar item)
/// and be resizable by dragging its edges — neither of which NSPopover supports.
final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class StatusBarController: NSObject, NSWindowDelegate {
    private static let defaultSize = NSSize(width: 380, height: 500)
    private static let widthDefaultsKey = "popupWidth"
    private static let heightDefaultsKey = "popupHeight"
    /// Distance between the caret and the edge of the popup.
    private static let anchorGap: CGFloat = 8

    private let statusItem: NSStatusItem
    private let panel: HistoryPanel
    private let store: HistoryStore
    private let monitor: ClipboardMonitor

    /// The app that was frontmost right before our popover took focus,
    /// so quick-paste can send Cmd+V back to the app the user was actually in.
    private var previousFrontmostApp: NSRunningApplication?
    private var globalClickMonitor: Any?
    private var keyMonitor: Any?
    private var preferencesWindowController: PreferencesWindowController?
    private let shortcutRecorder: ShortcutRecorder
    private let historyViewModel = HistoryViewModel()
    private var hasShownAccessibilityAlert = false
    /// When the panel last closed because it lost key status, so a click on the
    /// status item that dismissed it isn't immediately treated as a request to reopen.
    private var lastResignClose = Date.distantPast

    init(store: HistoryStore, monitor: ClipboardMonitor, shortcutRecorder: ShortcutRecorder) {
        self.store = store
        self.monitor = monitor
        self.shortcutRecorder = shortcutRecorder
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.panel = HistoryPanel(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Echo")
            button.toolTip = "Echo — Clipboard History"
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        panel.title = "Echo Clipboard History"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentMinSize = NSSize(width: 300, height: 320)
        panel.delegate = self
        panel.contentViewController = NSHostingController(
            rootView: HistoryListView(
                store: store,
                viewModel: historyViewModel,
                onSelect: { [weak self] item in self?.selected(item) },
                onClear: { [weak self] in self?.store.clearAll() },
                onSettings: { [weak self] in self?.openPreferences() }
            )
        )
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showMenu()
        } else {
            toggle()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        if !PasteSimulator.hasAccessibilityPermission {
            let item = menu.addItem(withTitle: "⚠️ Enable Accessibility to Paste…",
                                    action: #selector(openAccessibilitySettings),
                                    keyEquivalent: "")
            item.target = self
            menu.addItem(.separator())
        }
        let clearItem = menu.addItem(withTitle: "Clear History…", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        clearItem.isEnabled = !store.items.isEmpty
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openPreferences), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Echo", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openAccessibilitySettings() {
        PasteSimulator.openAccessibilitySettings()
    }

    @objc private func clearHistory() {
        close()
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "All saved text and images will be removed from Echo. This cannot be undone."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear History")
        if alert.runModal() == .alertSecondButtonReturn { store.clearAll() }
    }

    @objc private func openPreferences() {
        close()
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(recorder: shortcutRecorder)
        }
        preferencesWindowController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func toggle() {
        if panel.isVisible {
            close()
        } else {
            // Clicking the status item to dismiss the panel already closed it by taking
            // key status away; without this the same click would reopen it immediately.
            guard Date().timeIntervalSince(lastResignClose) > 0.25 else { return }
            open()
        }
    }

    func open() {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousFrontmostApp = frontmost
        }
        historyViewModel.reset()
        positionPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func close() {
        panel.orderOut(nil)
        removeKeyMonitor()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard panel.isVisible else { return }
        lastResignClose = Date()
        close()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        let size = panel.frame.size
        UserDefaults.standard.set(Double(size.width), forKey: Self.widthDefaultsKey)
        UserDefaults.standard.set(Double(size.height), forKey: Self.heightDefaultsKey)
    }

    // MARK: - Placement

    /// Opens the panel just below the text caret (falling back to the mouse), sized to
    /// whatever the user last dragged it to, clamped so no edge lands off-screen.
    private func positionPanel() {
        let anchor = Self.caretScreenRect() ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor.origin) })
            ?? NSScreen.main else { return }
        let visible = screen.visibleFrame

        var size = savedSize()
        size.width = min(size.width, visible.width)
        size.height = min(size.height, visible.height)

        var origin = NSPoint(x: anchor.minX, y: anchor.minY - Self.anchorGap - size.height)
        if origin.y < visible.minY {
            // No room underneath: flip above the caret if that fits.
            let above = anchor.maxY + Self.anchorGap
            origin.y = (above + size.height <= visible.maxY) ? above : visible.minY
        }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)

        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }

    private func savedSize() -> NSSize {
        let defaults = UserDefaults.standard
        let width = defaults.double(forKey: Self.widthDefaultsKey)
        let height = defaults.double(forKey: Self.heightDefaultsKey)
        guard width > 0, height > 0 else { return Self.defaultSize }
        return NSSize(width: max(width, panel.contentMinSize.width), height: max(height, panel.contentMinSize.height))
    }

    /// Screen rect of the insertion point in the frontmost app, in Cocoa coordinates.
    /// Nil when Accessibility permission is missing or the focused element isn't text,
    /// in which case the caller falls back to the mouse location.
    private static func caretScreenRect() -> NSRect? {
        guard PasteSimulator.hasAccessibilityPermission else { return nil }

        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement

        var range: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success,
              let range else { return nil }

        var bounds: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element,
                                                         kAXBoundsForRangeParameterizedAttribute as CFString,
                                                         range,
                                                         &bounds) == .success,
              let bounds, CFGetTypeID(bounds) == AXValueGetTypeID() else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(bounds as! AXValue, .cgRect, &rect) else { return nil }
        guard let primary = NSScreen.screens.first else { return nil }

        // Accessibility reports top-left origin coordinates; windows use bottom-left.
        return NSRect(x: rect.minX,
                      y: primary.frame.maxY - rect.maxY,
                      width: rect.width,
                      height: rect.height)
    }

    // MARK: - Keyboard navigation

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, NSApp.keyWindow === self.panel,
                  self.panel.attachedSheet == nil else { return event }
            return self.handleKeyDown(event)
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    /// Returns nil to swallow the event, or the event itself to let it pass through
    /// (e.g. so normal typing still reaches the search field).
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let filtered = historyViewModel.filteredItems(from: store.items)
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "f": historyViewModel.focusSearch = UUID(); return nil
            case ",": openPreferences(); return nil
            default: return event
            }
        }
        let editingSearch = panel.firstResponder is NSTextView
        if let editor = panel.firstResponder as? NSTextView, editor.hasMarkedText() {
            return event // Let the input method commit composed text first.
        }
        switch event.keyCode {
        case 125 where editingSearch: // Down arrow
            historyViewModel.moveSelection(by: 1, count: filtered.count)
            return nil
        case 126 where editingSearch: // Up arrow
            historyViewModel.moveSelection(by: -1, count: filtered.count)
            return nil
        case 36, 76: // Return / keypad Enter
            if filtered.indices.contains(historyViewModel.selectedIndex) {
                selected(filtered[historyViewModel.selectedIndex])
            }
            return nil
        case 53: // Escape
            close()
            return nil
        default:
            return event
        }
    }

    private func selected(_ item: ClipboardItem) {
        writeToPasteboard(item)
        close()

        // Without Accessibility permission the synthetic Cmd+V is silently discarded
        // by the system, so surface it instead of appearing to do nothing.
        guard PasteSimulator.hasAccessibilityPermission else {
            showAccessibilityAlertIfNeeded()
            return
        }

        guard let target = previousFrontmostApp, !target.isTerminated else { return }
        target.activate(options: [.activateIgnoringOtherApps])
        PasteSimulator.pasteWhenActive(target)
    }

    private func showAccessibilityAlertIfNeeded() {
        guard !hasShownAccessibilityAlert else { return }
        hasShownAccessibilityAlert = true

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Echo needs Accessibility permission to paste"
        alert.informativeText = """
            The item was copied to your clipboard, but Echo can't press ⌘V for you \
            until it's allowed under Privacy & Security › Accessibility.

            If “Echo” is already listed there, remove it with the − button and add \
            /Applications/Echo.app again — the old entry goes stale when the app is rebuilt. \
            Then quit and reopen Echo.
            """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")

        if alert.runModal() == .alertFirstButtonReturn {
            PasteSimulator.openAccessibilitySettings()
        }
    }

    private func writeToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.kind {
        case .text:
            pasteboard.setString(item.text ?? "", forType: .string)
        case .image:
            if let image = store.image(for: item), let tiff = image.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        }
        monitor.pendingProgrammaticItem = item
    }
}
