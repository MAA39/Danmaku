import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private init() {
        let view = PreferencesView()
        let hosting = NSHostingView(rootView: view)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
                            styleMask: [.titled, .closable, .utilityWindow],
                            backing: .buffered,
                            defer: false)
        panel.title = "Preferences"
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.contentView = hosting
        super.init(window: panel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        guard let w = window else { return }
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
