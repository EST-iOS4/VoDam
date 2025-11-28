//
//  SpeechService.swift
//  Vodam
//

import Speech
import AVFoundation

class SpeechService: NSObject {

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    
    private var transcriptContinuation: AsyncStream<String>.Continuation?

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
    
    func startLiveTranscription() -> AsyncStream<String> {
        stopLiveTranscription()
        
        return AsyncStream { continuation in
            self.transcriptContinuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                self.stopLiveTranscription()
            }
            
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.shouldReportPartialResults = true

            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.record, mode: .measurement)
                try audioSession.setActive(true)
            } catch {
                print("🎧 AudioSession 오류: \(error)")
                continuation.finish()
                return
            }

            let inputNode = self.audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }

            self.recognitionTask = self.recognizer?.recognitionTask(with: self.recognitionRequest!) { result, error in
                if let result {
                    let transcript = result.bestTranscription.formattedString
                    print("📝 실시간 변환:", transcript)
                    continuation.yield(transcript)  // ✅ 결과 전달
                }
                
                if let error {
                    print("❌ STT 오류:", error.localizedDescription)
                }
            }

            self.audioEngine.prepare()
            do {
                try self.audioEngine.start()
                print("🎧 실시간 STT 시작됨")
            } catch {
                print("❌ STT Start 오류:", error.localizedDescription)
                continuation.finish()
            }
        }
    }

    func stopLiveTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        transcriptContinuation?.finish()
        transcriptContinuation = nil

        print("🛑 실시간 STT 정지됨")
    }
}
