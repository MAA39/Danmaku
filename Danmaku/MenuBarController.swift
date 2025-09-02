import Cocoa

final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    override init() {
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "captions.bubble", accessibilityDescription: "Danmaku")
            button.imagePosition = .imageOnly
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let start = NSMenuItem(title: "Start Transcribe", action: #selector(didTapStart), keyEquivalent: "s")
        start.keyEquivalentModifierMask = [.command]
        start.target = self
        menu.addItem(start)

        let stop = NSMenuItem(title: "Stop", action: #selector(didTapStop), keyEquivalent: "x")
        stop.keyEquivalentModifierMask = [.command]
        stop.target = self
        menu.addItem(stop)

        menu.addItem(.separator())

        let prefs = NSMenuItem(title: "Preferences…", action: #selector(didTapPreferences), keyEquivalent: ",")
        prefs.keyEquivalentModifierMask = [.command]
        prefs.target = self
        menu.addItem(prefs)

        let dump = NSMenuItem(title: "Dump Latest 10 (Console)", action: #selector(didTapDumpLatest), keyEquivalent: "d")
        dump.keyEquivalentModifierMask = [.command, .shift]
        dump.target = self
        menu.addItem(dump)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(didTapQuit), keyEquivalent: "q")
        quit.keyEquivalentModifierMask = [.command]
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func didTapPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func didTapDumpLatest() {
        NotificationCenter.default.post(name: .danmakuDumpLatest, object: nil)
    }

    @objc private func didTapStart() {
        NotificationCenter.default.post(name: .danmakuStart, object: nil)
    }

    @objc private func didTapStop() {
        NotificationCenter.default.post(name: .danmakuStop, object: nil)
    }

    @objc private func didTapQuit() {
        NSApp.terminate(nil)
    }
}
