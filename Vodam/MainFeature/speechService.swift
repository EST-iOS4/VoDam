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

    func startLiveTranscription() {
        stopLiveTranscription()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
        } catch {
            print("🎧 AudioSession 오류: \(error)")
        }

        let inputNode = audioEngine.inputNode


        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest!) { result, error in
            if let result {
                print("📝 실시간 변환:", result.bestTranscription.formattedString)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("🎧 실시간 STT 시작됨")
        } catch {
            print("❌ STT Start 오류:", error.localizedDescription)
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

        print("🛑 실시간 STT 정지됨")
    }
}
