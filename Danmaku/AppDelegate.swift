import Cocoa
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var overlay: OverlayWindow!
    private let transcriber = TranscriptionCoordinator()
    private var store: ChunkStore!

    func applicationDidFinishLaunching(_ notification: Notification) {
        DanmakuPrefs.registerDefaults()

        menuBar = MenuBarController()
        overlay = OverlayWindow()
        overlay.orderFrontRegardless()

        // DB 初期化
        do { store = try ChunkStore() }
        catch { showAlert(message: "DB初期化エラー", info: "\(error)") }

        // 起動時に権限を準備
        transcriber.prepare { [weak self] result in
            DispatchQueue.main.async {
                if case .failure(let err) = result {
                    self?.showAlert(message: "権限エラー", info: "\(err)")
                }
            }
        }

        // メニュー操作で Start/Stop
        NotificationCenter.default.addObserver(forName: .danmakuStart, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.transcriber.isOnDeviceSupported == false {
                self.showAlert(message: "オンデバイス未対応",
                               info: "このMacではオフライン音声認識が使えません。")
                return
            }
            do { try self.transcriber.start() }
            catch {
                Log.stt.error("start failed: \(error.localizedDescription, privacy: .public)")
                self.showAlert(message: "開始できません", info: "\(error)")
            }
        }
        NotificationCenter.default.addObserver(forName: .danmakuStop, object: nil, queue: .main) { [weak self] _ in
            self?.transcriber.stop()
        }

        // 確定チャンクを保存（userInfo 形式/ object 辞書 両対応）
        NotificationCenter.default.addObserver(forName: .danmakuChunk, object: nil, queue: .main) { [weak self] n in
            var text: String?
            var started: Date?
            var ended: Date?
            if let ui = n.userInfo {
                text = ui["text"] as? String
                started = ui["startedAt"] as? Date
                ended = ui["endedAt"] as? Date
            } else if let obj = n.object as? [String: Any] {
                text = obj["text"] as? String
                started = obj["startedAt"] as? Date
                ended = obj["endedAt"] as? Date
            }
            guard let t = text, let s = started, let e = ended else { return }
            self?.store.insert(text: t, startedAt: s, endedAt: e)
            Log.db.info("chunk saved len=\(t.count, privacy: .public)")
            if DanmakuPrefs.inputInjectionEnabled {
                InputInjector.type(t + "\n")
            }
        }

        // デバッグ: 最新10件をコンソールにダンプ
        NotificationCenter.default.addObserver(forName: .danmakuDumpLatest, object: nil, queue: .main) { [weak self] _ in
            self?.store.latest(limit: 10) { rows in
                let f = ISO8601DateFormatter(); f.timeZone = TimeZone(secondsFromGMT: 0)
                for (date, text) in rows {
                    print("\(f.string(from: date)) \(text)")
                }
            }
        }

        // アクセシビリティ権限の促し（自動投入の前提）
        ensureAccessibilityPermission()
    }

    private func ensureAccessibilityPermission() {
        let opts: CFDictionary = [
            (kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String): true as CFBoolean
        ] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        Log.input.info(trusted ? "accessibility granted" : "accessibility not granted")
        // 権限が無ければ一時的にInput Insertionを無効化（ユーザ設定は尊重しつつ安全側に）
        if !trusted {
            DanmakuPrefs.inputInjectionEnabled = false
        }
    }

    private func showAlert(message: String, info: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .warning
        alert.runModal()
    }
}
