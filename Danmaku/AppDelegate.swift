import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var overlay: OverlayWindow!
    private let transcriber = TranscriptionCoordinator()
    private var store: ChunkStore!

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            catch { self.showAlert(message: "開始できません", info: "\(error)") }
        }
        NotificationCenter.default.addObserver(forName: .danmakuStop, object: nil, queue: .main) { [weak self] _ in
            self?.transcriber.stop()
        }

        // 確定チャンクを保存
        NotificationCenter.default.addObserver(forName: .danmakuChunk, object: nil, queue: .main) { [weak self] n in
            guard
                let text = n.userInfo?["text"] as? String,
                let started = n.userInfo?["startedAt"] as? Date,
                let ended = n.userInfo?["endedAt"] as? Date
            else { return }
            self?.store.insert(text: text, startedAt: started, endedAt: ended)
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
