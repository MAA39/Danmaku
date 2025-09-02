import Cocoa
import QuartzCore

final class OverlayWindow: NSWindow {
    private let contentContainer = NSView()
    private var rowOffset: CGFloat = 0 // 行ごとのオフセット
    private let rowStep: CGFloat = 44
    private let maxRows: CGFloat = 3

    convenience init() {
        let screen = NSScreen.main?.frame ?? .zero
        self.init(contentRect: screen,
                  styleMask: [.borderless],
                  backing: .buffered,
                  defer: false)
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        level = .statusBar

        contentView = contentContainer
        contentContainer.wantsLayer = true
        contentContainer.layer = CALayer()
        contentContainer.layer?.backgroundColor = NSColor.clear.cgColor

        // 確定チャンク受信 → 弾幕生成
        NotificationCenter.default.addObserver(forName: .danmakuChunk, object: nil, queue: .main) { [weak self] note in
            guard let text = note.userInfo?["text"] as? String, !text.isEmpty else { return }
            self?.spawn(text: text)
        }

        NotificationCenter.default.addObserver(forName: .danmakuPrefsChanged, object: nil, queue: .main) { [weak self] _ in
            // 設定変更に応じて行オフセットを軽くリセット
            self?.rowOffset = 0
        }
    }

    func spawn(text: String) {
        guard let layerHost = contentContainer.layer else { return }
        let screenWidth = frame.width
        let startX = screenWidth + 20

        // テキストレイヤ
        let textLayer = CATextLayer()
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        let fontSize = DanmakuPrefs.fontSize
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        textLayer.string = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.white
            ]
        )
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let height = ceil(textSize.height)
        let width = max(ceil(textSize.width) + 24, 120)

        let topInset = DanmakuPrefs.baselineY
        let y = min(max(frame.height - (topInset + rowOffset), 20), frame.height - height - 20)
        rowOffset += rowStep
        if rowOffset >= rowStep * maxRows { rowOffset = 0 }

        textLayer.frame = CGRect(x: startX, y: y, width: width, height: height)
        textLayer.alignmentMode = .left
        textLayer.truncationMode = .end
        textLayer.isWrapped = false
        textLayer.shadowOpacity = 0.9
        textLayer.shadowRadius = 3
        textLayer.shadowColor = NSColor.black.withAlphaComponent(0.65).cgColor
        textLayer.shadowOffset = .init(width: 0, height: -1)

        layerHost.addSublayer(textLayer)

        // 右→左 へゆっくり流す
        let endX = -width - 40
        let distance = startX - endX
        let speed: CGFloat = DanmakuPrefs.speed // px/s
        let duration = CFTimeInterval(distance / speed)

        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = startX + width/2
        animation.toValue = endX + width/2
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak textLayer] in
            textLayer?.removeFromSuperlayer()
        }
        textLayer.add(animation, forKey: "danmakuMove")
        CATransaction.commit()
    }
}
