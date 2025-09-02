import Cocoa
import ApplicationServices

enum InputInjector {
    @discardableResult
    static func ensureAccessibility(prompt: Bool = true) -> Bool {
        let opts: CFDictionary = [
            (kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String): (prompt as CFBoolean)
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    static func type(_ text: String) {
        guard ensureAccessibility(prompt: true) else {
            Log.input.error("accessibility not granted")
            return
        }
        guard text.isEmpty == false else { return }

        Log.input.info("inject start len=\(text.count, privacy: .public)")
        let source = CGEventSource(stateID: .combinedSessionState)
        for scalar in text.unicodeScalars {
            var u = [UniChar(scalar.value)]
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
               let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                keyDown.keyboardSetUnicodeString(stringLength: 1, unicodeString: &u)
                keyUp.keyboardSetUnicodeString(stringLength: 1, unicodeString: &u)
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }
}

