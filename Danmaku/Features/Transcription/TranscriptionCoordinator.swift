import Foundation
import AVFoundation
import Speech
import Accelerate

/// 音声認識の開始/停止、権限、オンデバイス可否チェックを一元管理するコーディネータ。
/// - 認識は **オンデバイス必須**（supportsOnDeviceRecognition=false なら開始しない）
/// - 中間結果は画面に出さず、**確定テキストのみ**を .danmakuChunk 通知で投げる
final class TranscriptionCoordinator {
    // MARK: - Public API

    /// 起動時に一回だけ呼ぶ。権限の事前確認を済ませる。
    func prepare(completion: @escaping (Result<Void, Error>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                completion(.success(()))
            case .denied:
                completion(.failure(TranscriptionError.permissionDenied("音声認識の許可が必要です")))
            case .restricted, .notDetermined:
                completion(.failure(TranscriptionError.permissionDenied("音声認識がこのMacで利用できません")))
            @unknown default:
                completion(.failure(TranscriptionError.unknown))
            }
        }
    }

    /// 開始（オンデバイス不可や権限不足ならアラートを推奨）
    func start() throws {
        guard isOnDeviceSupported else {
            throw TranscriptionError.onDeviceUnsupported("オンデバイス音声認識に未対応の端末/OSです")
        }
        try configureSessionIfNeeded()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.requiresOnDeviceRecognition = true  // ←ここが肝

        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw TranscriptionError.unavailable("音声認識サービスが現在利用できません")
        }

        // 既存タスク掃除
        recognitionTask?.cancel(); recognitionTask = nil
        currentChunkStart = nil

        // マイク音声を流し込む
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.handleSilence(buffer: buffer, format: format) // 無音監視（Step6/7で活用）
        }

        try audioEngine.start()

        // 認識コールバック：確定だけ束ねて吐く
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self else { return }
            if let r = result, r.isFinal {
                let text = r.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    let started = self.currentChunkStart ?? Date()
                    let ended = Date()
                    NotificationCenter.default.post(name: .danmakuChunk, object: nil, userInfo: [
                        "text": text,
                        "startedAt": started,
                        "endedAt": ended
                    ])
                }
                self.currentChunkStart = nil
                self.flushSilenceState()
            }
            if error != nil {
                self.stop() // エラー時は安全に停止
            }
        }
    }

    /// 停止
    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        flushSilenceState()
        currentChunkStart = nil
    }

    // MARK: - On-device support

    /// このMacが「日本語のオンデバイス認識」をサポートしているか
    var isOnDeviceSupported: Bool {
        recognizer?.supportsOnDeviceRecognition ?? false
    }

    // MARK: - Private

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // 無音検出（移動平均で ~2s 無音を検知）
    private var silenceWindow: [Float] = []
    private var lastVoiceAt: TimeInterval = Date.timeIntervalSinceReferenceDate
    private let silenceThresholdDb: Float = -45  // だいたいこの辺（端末次第で微調整）
    private let silenceCutSeconds: TimeInterval = 2.0

    // チャンクの開始推定（音が戻った瞬間を開始とみなす）
    private var currentChunkStart: Date? = nil

    private func configureSessionIfNeeded() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #else
        // macOS では特に設定不要
        #endif
    }

    private func handleSilence(buffer: AVAudioPCMBuffer, format: AVAudioFormat) {
        guard let ch = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        var rms: Float = 0
        vDSP_rmsqv(ch, 1, &rms, vDSP_Length(count))
        var db = 20 * log10f(rms)
        if !db.isFinite { db = -100 }

        // 移動平均（8サンプル程度）
        silenceWindow.append(db); if silenceWindow.count > 8 { silenceWindow.removeFirst() }
        let avg = silenceWindow.reduce(0, +) / Float(silenceWindow.count)

        if avg > silenceThresholdDb {
            if currentChunkStart == nil { currentChunkStart = Date() }
            lastVoiceAt = Date.timeIntervalSinceReferenceDate
        } else {
            let now = Date.timeIntervalSinceReferenceDate
            if now - lastVoiceAt > silenceCutSeconds {
                // → 無音2秒：ここで認識の“確定”を待つ。r.isFinal 側で吐くためここは状態リセットのみ。
                flushSilenceState()
            }
        }
    }

    private func flushSilenceState() {
        silenceWindow.removeAll(keepingCapacity: true)
        lastVoiceAt = Date.timeIntervalSinceReferenceDate
    }
}

// MARK: - Errors & Notifications

enum TranscriptionError: Error {
    case permissionDenied(String)
    case onDeviceUnsupported(String)
    case unavailable(String)
    case unknown
}

extension Notification.Name {
    /// 確定チャンクができたときに text を userInfo["text"] で投げる
    static let danmakuChunk = Notification.Name("danmaku.chunk")
}
