import Foundation
import AppKit

extension Notification.Name {
    static let danmakuPrefsChanged = Notification.Name("danmaku.prefs.changed")
    static let danmakuDumpLatest = Notification.Name("danmaku.dump.latest")
}

struct DanmakuPrefs {
    private struct Keys {
        static let speed = "danmaku.speed"
        static let fontSize = "danmaku.fontSize"
        static let baselineY = "danmaku.baselineY"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Keys.speed: 60.0,
            Keys.fontSize: 28.0,
            Keys.baselineY: 80.0,
        ])
    }

    static var speed: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: Keys.speed)
            return v == 0 ? 60 : CGFloat(v)
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: Keys.speed)
            NotificationCenter.default.post(name: .danmakuPrefsChanged, object: nil)
        }
    }

    static var fontSize: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: Keys.fontSize)
            return v == 0 ? 28 : CGFloat(v)
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: Keys.fontSize)
            NotificationCenter.default.post(name: .danmakuPrefsChanged, object: nil)
        }
    }

    static var baselineY: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: Keys.baselineY)
            return v == 0 ? 80 : CGFloat(v)
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: Keys.baselineY)
            NotificationCenter.default.post(name: .danmakuPrefsChanged, object: nil)
        }
    }
}
