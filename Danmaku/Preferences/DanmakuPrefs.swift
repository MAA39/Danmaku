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

    // Allowed ranges (hard guards)
    private static let speedRange: ClosedRange<CGFloat> = 20.0...150.0
    private static let fontRange: ClosedRange<CGFloat> = 14.0...48.0
    private static let baselineRange: ClosedRange<CGFloat> = 40.0...300.0

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
            let clamped = min(max(newValue, speedRange.lowerBound), speedRange.upperBound)
            UserDefaults.standard.set(Double(clamped), forKey: Keys.speed)
            NotificationCenter.default.post(name: .danmakuPrefsChanged, object: nil)
        }
    }

    static var fontSize: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: Keys.fontSize)
            return v == 0 ? 28 : CGFloat(v)
        }
        set {
            let clamped = min(max(newValue, fontRange.lowerBound), fontRange.upperBound)
            UserDefaults.standard.set(Double(clamped), forKey: Keys.fontSize)
            NotificationCenter.default.post(name: .danmakuPrefsChanged, object: nil)
        }
    }

    static var baselineY: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: Keys.baselineY)
            return v == 0 ? 80 : CGFloat(v)
        }
        set {
            let clamped = min(max(newValue, baselineRange.lowerBound), baselineRange.upperBound)
            UserDefaults.standard.set(Double(clamped), forKey: Keys.baselineY)
            NotificationCenter.default.post(name: .danmakuPrefsChanged, object: nil)
        }
    }
}
