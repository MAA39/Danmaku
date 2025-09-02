import Cocoa
import QuartzCore

final class OverlayWindow: NSWindow {
    private let contentContainer = NSView()
    // lanes to reduce overlap (上から等間隔のレーン)
    private let lanes: Int = 8
    private var nextLane: Int = 0
    private let laneHeight: CGFloat = 28
    // 1チャンク＝1レイヤ（partialで文字列更新）
    private var activeLayer: CATextLayer?
    private var activeUtteranceID: Int?
    private var closedUtteranceID: Int?

    convenience init() {
        let screen = NSScreen.main?.frame ?? .zero
        let frac = DanmakuPrefs.overlayWidthFraction
        let width = max(100, screen.width * frac)
        let rect = NSRect(x: 0, y: 0, width: width, height: screen.height)
        self.init(contentRect: rect,
                  styleMask: [.borderless],
                  backing: .buffered,
                  defer: false)
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        level = .screenSaver

        contentView = contentContainer
        contentContainer.wantsLayer = true
        contentContainer.layer = CALayer()
        contentContainer.layer?.backgroundColor = NSColor.clear.cgColor
        contentContainer.layer?.masksToBounds = true // クリップして省略記号を使わない

        // 部分テキスト：アクティブレイヤを生成/更新のみ（新規スポーンしない）
        NotificationCenter.default.addObserver(forName: .danmakuPartialText, object: nil, queue: .main) { [weak self] note in
            guard let self = self, let info = note.userInfo else { return }
            let text = (info["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard text.isEmpty == false else { return }
            guard let uid = info["utteranceID"] as? Int else { return }

            if let closed = self.closedUtteranceID, closed == uid {
                Log.overlay.debug("drop partial for closed uid=\(uid, privacy: .public)")
                return
            }
            if self.activeUtteranceID != uid || self.activeLayer == nil {
                self.closedUtteranceID = nil
                self.activeUtteranceID = uid
                _ = self.ensureActiveLayer(initialText: text)
                self.updateActiveLayerText(text)
                return
            }
            self.updateActiveLayerText(text)
        }
        // 確定テキスト：表示はせず、IDをクローズして以後の同IDパーシャルを無視
        NotificationCenter.default.addObserver(forName: .danmakuChunk, object: nil, queue: .main) { [weak self] note in
            guard let self = self, let info = note.userInfo else { return }
            guard let uid = info["utteranceID"] as? Int else { return }
            // レイヤの最終表示は不要。IDのみクローズ。
            if self.activeUtteranceID == uid {
                self.closedUtteranceID = uid
                self.activeLayer = nil  // レイヤはアニメで流れて消える
                self.activeUtteranceID = nil
            } else {
                self.closedUtteranceID = uid
            }
        }

        NotificationCenter.default.addObserver(forName: .danmakuPrefsChanged, object: nil, queue: .main) { [weak self] _ in
            // 設定変更に応じてレイアウトを更新
            self?.applyWidthFraction()
        }
    }

    private func applyWidthFraction() {
        guard let screen = NSScreen.main?.frame else { return }
        let frac = DanmakuPrefs.overlayWidthFraction
        let width = max(100, screen.width * frac)
        let rect = NSRect(x: 0, y: 0, width: width, height: screen.height)
        setFrame(rect, display: true)
    }

    private let horizontalPadding: CGFloat = 24

    private func textWidth(_ s: String, font: NSFont) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let w = (s as NSString).boundingRect(with: .zero, options: [], attributes: attrs).width
        return ceil(w)
    }

    private var pointsPerSecond: CGFloat {
        let winW = max(self.frame.width, 1)
        let baseSec = max(DanmakuPrefs.overlayTraverseSec, 0.1)
        return winW / CGFloat(baseSec)
    }

    private func startDanmakuAnimation(layer: CALayer, textWidth: CGFloat) {
        let winW = self.frame.width
        let travel = winW + textWidth
        let duration = Double(travel / pointsPerSecond)

        let anim = CABasicAnimation(keyPath: "transform.translation.x")
        anim.fromValue = 0
        anim.toValue = -(travel)
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak layer] in
            layer?.removeFromSuperlayer()
            if let self, self.activeLayer === layer { self.activeLayer = nil }
        }
        layer.add(anim, forKey: "slide")
        CATransaction.commit()
        Log.overlay.debug("spawn width=\(textWidth, privacy: .public) travel=\(travel, privacy: .public) dur=\(duration, privacy: .public)")
    }

    private func ensureActiveLayer(initialText: String = "") -> CATextLayer {
        if let layer = activeLayer { return layer }
        guard let layerHost = contentContainer.layer else { fatalError("no layer host") }

        let fontSize = DanmakuPrefs.fontSize
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let initialWidth = max(1, textWidth(initialText, font: font)) + 2 * horizontalPadding
        let height = ceil(max(("A" as NSString).size(withAttributes: [.font: font]).height, laneHeight))

        // レーンのY位置（上から lanes 本）
        let topInset = DanmakuPrefs.baselineY
        let laneIndex = nextLane % max(lanes, 1)
        nextLane += 1
        let yTopFromTop = CGFloat(laneIndex) * (height + 8)
        let y = min(max(frame.height - (topInset + yTopFromTop), 20), frame.height - height - 20)

        // 右→左: 初期位置は右外
        let startX = frame.width + initialWidth/2

        let textLayer = CATextLayer()
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        textLayer.string = NSAttributedString(string: initialText, attributes: [
            .font: font,
            .foregroundColor: NSColor.white
        ])
        textLayer.bounds = CGRect(x: 0, y: 0, width: initialWidth, height: height)
        textLayer.position = CGPoint(x: startX, y: y)
        textLayer.alignmentMode = .left
        textLayer.truncationMode = .none
        textLayer.isWrapped = false
        textLayer.allowsFontSubpixelQuantization = true
        textLayer.shadowOpacity = 0.9
        textLayer.shadowRadius = 3
        textLayer.shadowColor = NSColor.black.withAlphaComponent(0.65).cgColor
        textLayer.shadowOffset = .init(width: 0, height: -1)

        layerHost.addSublayer(textLayer)

        // 開始時点の幅でアニメ計算（途中成長はマスクで処理）
        startDanmakuAnimation(layer: textLayer, textWidth: initialWidth)

        activeLayer = textLayer
        return textLayer
    }

    private func updateActiveLayerText(_ text: String) {
        guard let layer = activeLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let fontSize = DanmakuPrefs.fontSize
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        layer.string = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: NSColor.white
        ])
        // 必要に応じて幅を広げる（トランケーションを無効化しているため、省略は出ない）
        let needed = textWidth(text, font: font) + 2 * horizontalPadding
        if needed > layer.bounds.width {
            let oldW = layer.bounds.width
            layer.bounds.size.width = needed
            Log.overlay.debug("grow width \(oldW, privacy: .public) -> \(needed, privacy: .public)")
        }
        CATransaction.commit()
    }
}
