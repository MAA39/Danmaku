import Foundation
import AVFoundation
import Speech
import QuartzCore
import Accelerate

/// 安定した音声→STT配線（bus 0 に tap → engine start → recognition 開始）
final class TranscriptionCoordinator {
    // MARK: - Lifecycle / Auth
    func prepare(completion: @escaping (Result<Void, Error>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized: completion(.success(()))
            case .denied: completion(.failure(TranscriptionError.permissionDenied("音声認可が必要です")))
            case .restricted, .notDetermined: completion(.failure(TranscriptionError.permissionDenied("音声認識がこのMacで利用できません")))
            @unknown default: completion(.failure(TranscriptionError.unknown))
            }
        }
    }

    var isOnDeviceSupported: Bool { recognizer?.supportsOnDeviceRecognition ?? false }

    // MARK: - Start/Stop
    func start() throws {
        Log.stt.info("start requested")
        stop() // idempotent

        // macOS: AVAudioSession は不要
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if #available(macOS 12.0, *) { req.requiresOnDeviceRecognition = true }
        request = req

        let input = audioEngine.inputNode
        let format = input.inputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.request?.append(buffer)
            // RMSヒステリシスで無音を判定
            if let ch = buffer.floatChannelData?[0] {
                let count = Int(buffer.frameLength)
                var rms: Float = 0
                vDSP_rmsqv(ch, 1, &rms, vDSP_Length(count))
                if !rms.isFinite { rms = 0 }
                self.rmsMovingAvg = self.rmsMovingAvg * 0.8 + rms * 0.2
                let frameSec = Double(buffer.frameLength) / format.sampleRate
                if self.rmsMovingAvg < self.silenceRmsThreshold {
                    self.silentConsecutiveCount += 1
                } else {
                    self.silentConsecutiveCount = 0
                }
                let silentSeconds = Double(self.silentConsecutiveCount) * frameSec
                let gap = DanmakuPrefs.silenceGapSec
                if self.hasActiveUtterance && silentSeconds >= gap {
                    self.finishChunk(with: nil)
                    self.silentConsecutiveCount = 0
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        Log.audio.info("audioEngine started: \(self.audioEngine.isRunning, privacy: .public)")

        recognitionTask = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                let full = r.bestTranscription.formattedString
                if !full.isEmpty {
                    // 差分抽出：共通接頭辞を除いた「新規末尾」だけを取り出す
                    let prefixLen = full.commonPrefix(with: lastPartialFull).count
                    let startIdx = full.index(full.startIndex, offsetBy: prefixLen)
                    var suffix = String(full[startIdx...])
                    // 空白のみは破棄（ノイズ除去）
                    suffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)

                    let now = CACurrentMediaTime()
                    if !suffix.isEmpty && suffix.count >= minEmitChars && (now - lastEmitAt) >= minEmitGap {
                        // 発話ID開始/ストラグラー抑止
                        if !hasActiveUtterance {
                            if (now - lastFinalizeAt) < 0.30 {
                                // 確定直後300msは遅延パーシャルを無視
                                return
                            }
                            currentUtteranceID &+= 1
                            hasActiveUtterance = true
                            if self.currentChunkStartDate == nil { self.currentChunkStartDate = Date() }
                        }
                        // オーバーレイは "全文" を更新（伸び続ける体感）。ログは差分を表示。
                        NotificationCenter.default.post(name: .danmakuPartialText, object: nil, userInfo: [
                            "text": full,
                            "utteranceID": currentUtteranceID
                        ])
                        Log.stt.debug("partial diff: \"\(suffix, privacy: .public)\"")
                        lastEmitAt = now
                    }
                    lastPartialFull = full

                    self.lastTextTimestamp = CACurrentMediaTime()
                    if self.currentChunkStartDate == nil { self.currentChunkStartDate = Date() }
                }
                if r.isFinal {
                    self.finishChunk(with: r.bestTranscription.formattedString)
                }
            }
            if let e = error {
                Log.stt.error("recognition error: \(e.localizedDescription, privacy: .public)")
            }
        }

        scheduleSilenceTick()
    }

    func stop() {
        Log.stt.info("stop requested")
        recognitionTask?.cancel(); recognitionTask = nil
        request?.endAudio(); request = nil
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
        currentChunkStartDate = nil
        hasActiveUtterance = false
        lastPartialFull = ""
        silentConsecutiveCount = 0
    }

    // MARK: - Silence / Finalize
    private func scheduleSilenceTick() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.silenceTick()
        }
    }

    private func silenceTick() {
        let gap = DanmakuPrefs.silenceGapSec
        let now = CACurrentMediaTime()
        if currentChunkStartDate != nil, (now - lastTextTimestamp) >= gap {
            finishChunk(with: nil)
        }
        scheduleSilenceTick()
    }

    private func finishChunk(with text: String?) {
        // textがnilなら、最後に観測した全文(lastPartialFull)を採用
        let candidateA = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateB = lastPartialFull.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalText: String? = {
            if let a = candidateA, a.isEmpty == false { return a }
            return candidateB.isEmpty ? nil : candidateB
        }()

        guard let startedAt = currentChunkStartDate else {
            currentChunkStartDate = nil
            hasActiveUtterance = false
            return
        }
        guard let s = finalText else {
            currentChunkStartDate = nil
            hasActiveUtterance = false
            lastPartialFull = ""
            lastFinalizeAt = CACurrentMediaTime()
            return
        }

        let endedAt = Date()
        NotificationCenter.default.post(name: .danmakuChunk, object: nil, userInfo: [
            "text": s,
            "startedAt": startedAt,
            "endedAt": endedAt,
            "utteranceID": currentUtteranceID
        ])
        Log.stt.info("final chunk: \(s, privacy: .public)")
        // 次のチャンクに備える
        currentChunkStartDate = nil
        hasActiveUtterance = false
        lastPartialFull = ""
        lastFinalizeAt = CACurrentMediaTime()
    }

    // MARK: - Internals
    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var lastTextTimestamp: TimeInterval = 0
    private var currentChunkStartDate: Date?
    private var currentUtteranceID: Int = 0
    private var hasActiveUtterance: Bool = false
    private var lastFinalizeAt: CFTimeInterval = 0
    // 無音ヒステリシス
    private var silentConsecutiveCount: Int = 0
    private var rmsMovingAvg: Float = 0
    private let silenceRmsThreshold: Float = 0.006 // ~ -45dB

    // --- partial coalescing state ---
    private var lastPartialFull: String = ""
    private var lastEmitAt: CFTimeInterval = 0
    private let minEmitChars = 1
    private let minEmitGap: CFTimeInterval = 0.15 // 150 ms for snappy partials
}

enum TranscriptionError: Error { case permissionDenied(String); case onDeviceUnsupported(String); case unavailable(String); case unknown }
