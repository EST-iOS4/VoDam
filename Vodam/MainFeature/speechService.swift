//
//  SpeechService.swift
//

import Speech
import AVFoundation

class SpeechService: NSObject {

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    
    private var transcriptContinuation: AsyncStream<String>.Continuation?
    
    private var isStarted = false

    override init() {
        super.init()
        requestAuthorization()
    }

    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                print("🎤 STT 사용 허가됨")
            default:
                print("🚫 STT 권한 거부됨")
            }
        }
    }

    // MARK: - START
    func startLiveTranscription() -> AsyncStream<String> {
        if isStarted, let continuation = transcriptContinuation {
            return AsyncStream { continuation in
                continuation.onTermination = { _ in }
            }
        }

        isStarted = true
        
        return AsyncStream { continuation in
            self.transcriptContinuation = continuation
            
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.shouldReportPartialResults = true

            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.record, mode: .measurement)
                try audioSession.setActive(true)
            } catch {
                print("🎧 AudioSession 오류:", error)
                continuation.finish()
                return
            }

            let inputNode = self.audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }

            self.recognitionTask = self.recognizer?.recognitionTask(with: self.recognitionRequest!) { result, error in
                if let result {
                    let transcript = result.bestTranscription.formattedString
                    continuation.yield(transcript)
                }
                
                if let error {
                    print("❌ STT 오류:", error.localizedDescription)
                }
            }

            do {
                self.audioEngine.prepare()
                try self.audioEngine.start()
                print("🎧 실시간 STT 시작됨")
            } catch {
                print("❌ STT Start 오류:", error)
                continuation.finish()
            }
        }
    }

    // MARK: - PAUSE
    func pauseTranscription() {
        if audioEngine.isRunning {
            audioEngine.pause()
            print("⏸️ STT 일시정지됨")
        }
    }

    // MARK: - RESUME
    func resumeTranscription() {
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                print("▶️ STT 재개됨")
            } catch {
                print("❌ STT 재개 오류:", error.localizedDescription)
            }
        }
    }

    // MARK: - STOP (완전 종료)
    func stopLiveTranscription() {
        isStarted = false

        recognitionTask?.finish()
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        
        transcriptContinuation?.finish()
        transcriptContinuation = nil
        
        print("🛑 STT 완전 종료됨")
    }
}
