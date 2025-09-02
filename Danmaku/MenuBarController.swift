import Cocoa

final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var startItem: NSMenuItem!
    private var stopItem: NSMenuItem!

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
        startItem = NSMenuItem(title: "Start Transcribe", action: #selector(didTapStart), keyEquivalent: "s")
        startItem.keyEquivalentModifierMask = [.command]
        startItem.target = self
        menu.addItem(startItem)

        stopItem = NSMenuItem(title: "Stop", action: #selector(didTapStop), keyEquivalent: "x")
        stopItem.keyEquivalentModifierMask = [.command]
        stopItem.target = self
        stopItem.isHidden = true
        stopItem.isEnabled = false
        menu.addItem(stopItem)

        menu.addItem(.separator())

        let prefs = NSMenuItem(title: "Preferences…", action: #selector(didTapPreferences), keyEquivalent: ",")
        prefs.keyEquivalentModifierMask = [.command]
        prefs.target = self
        menu.addItem(prefs)

        let injection = NSMenuItem(title: "Input Insertion", action: #selector(toggleInputInsertion), keyEquivalent: "i")
        injection.keyEquivalentModifierMask = [.command]
        injection.target = self
        injection.state = DanmakuPrefs.inputInjectionEnabled ? .on : .off
        menu.addItem(injection)

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
        startItem.isEnabled = false
        startItem.isHidden = true
        stopItem.isEnabled = true
        stopItem.isHidden = false
        NotificationCenter.default.post(name: .danmakuStart, object: nil)
    }

    @objc private func didTapStop() {
        stopItem.isEnabled = false
        stopItem.isHidden = true
        startItem.isEnabled = true
        startItem.isHidden = false
        NotificationCenter.default.post(name: .danmakuStop, object: nil)
    }

    @objc private func didTapQuit() {
        NSApp.terminate(nil)
    }

    @objc private func toggleInputInsertion(_ sender: NSMenuItem) {
        let newValue = !DanmakuPrefs.inputInjectionEnabled
        DanmakuPrefs.inputInjectionEnabled = newValue
        sender.state = newValue ? .on : .off
    }
}
