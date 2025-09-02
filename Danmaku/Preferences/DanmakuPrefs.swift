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
        static let overlayTraverseSec = "danmaku.overlay.traverseSec"
        static let overlayWidthFraction = "danmaku.overlay.widthFraction"
        static let inputInjectionEnabled = "danmaku.input.injectionEnabled"
        static let silenceGapSec = "danmaku.transcribe.silenceGapSec"
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
            Keys.overlayTraverseSec: 5.0,
            Keys.overlayWidthFraction: 0.6,
            Keys.inputInjectionEnabled: false,
            Keys.silenceGapSec: 1.0,
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

    // MARK: - New Settings (Task 2)

    /// Overlay traverse duration in seconds (left→right). Range: 2.0 ... 12.0, Default: 5.0
    static var overlayTraverseSec: Double {
        get {
            let v = UserDefaults.standard.double(forKey: Keys.overlayTraverseSec)
            let d = (v == 0) ? 5.0 : v
            return min(max(d, 2.0), 12.0)
        }
        set {
            let clamped = min(max(newValue, 2.0), 12.0)
            UserDefaults.standard.set(clamped, forKey: Keys.overlayTraverseSec)
            NotificationCenter.default.post(name: .danmakuPrefsChanged, object: nil)
        }
    }

    /// Overlay width as a fraction of screen width. Range: 0.3 ... 1.0, Default: 0.6
    static var overlayWidthFraction: Double {
        get {
            let v = UserDefaults.standard.double(forKey: Keys.overlayWidthFraction)
            let d = (v == 0) ? 0.6 : v
            return min(max(d, 0.3), 1.0)
        }
        set {
            let clamped = min(max(newValue, 0.3), 1.0)
            UserDefaults.standard.set(clamped, forKey: Keys.overlayWidthFraction)
            NotificationCenter.default.post(name: .danmakuPrefsChanged, object: nil)
        }
    }

    /// When true, finalized chunk text is inserted into the currently focused input. Default: false
    static var inputInjectionEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.inputInjectionEnabled) == nil { return false }
            return UserDefaults.standard.bool(forKey: Keys.inputInjectionEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.inputInjectionEnabled)
            NotificationCenter.default.post(name: .danmakuPrefsChanged, object: nil)
        }
    }

    /// Silence gap for chunk boundary (seconds). Range: 0.5 ... 5.0, Default: 2.0
    static var silenceGapSec: Double {
        get {
            let v = UserDefaults.standard.double(forKey: Keys.silenceGapSec)
            let d = (v == 0) ? 2.0 : v
            return min(max(d, 0.5), 5.0)
        }
        set {
            let clamped = min(max(newValue, 0.5), 5.0)
            UserDefaults.standard.set(clamped, forKey: Keys.silenceGapSec)
            NotificationCenter.default.post(name: .danmakuPrefsChanged, object: nil)
        }
    }
}
