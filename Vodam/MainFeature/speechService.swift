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
    
    private let queue = DispatchQueue(label: "com.app.speechService", qos: .userInitiated)
    private var _isStarted = false
    private var isStarted: Bool {
        get { queue.sync { _isStarted } }
        set { queue.sync { _isStarted = newValue } }
    }
    
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
        if isStarted {
            stopLiveTranscription()
        }
        
        isStarted = true
        
        return AsyncStream { [weak self] continuation in
            guard let self = self else {
                continuation.finish()
                return
            }
            
            continuation.onTermination = { [weak self] _ in
                self?.cleanupResources()
            }
            
            self.transcriptContinuation = continuation
            
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.recognitionRequest = request
            
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                print("🎧 AudioSession 오류:", error)
                continuation.finish()
                return
            }
            
            let inputNode = self.audioEngine.inputNode
            let hardwareFormat = inputNode.inputFormat(forBus: 0)
            
            guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
                print("❌ 하드웨어 포맷 무효")
                continuation.finish()
                return
            }
            
            inputNode.removeTap(onBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { buffer, _ in
                request.append(buffer)
            }
            
            guard let recognizer = self.recognizer else {
                print("❌ Recognizer 없음")
                continuation.finish()
                return
            }
            
            self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let result = result {
                    self?.transcriptContinuation?.yield(result.bestTranscription.formattedString)
                    
                    if result.isFinal {
                        self?.transcriptContinuation?.finish()
                    }
                }
                
                if let error = error {
                    let nsError = error as NSError
                    guard nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 216 else { return }
                    print("❌ STT 오류:", error.localizedDescription)
                    self?.transcriptContinuation?.finish()
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
        guard audioEngine.isRunning else { return }
        audioEngine.pause()
        print("⏸️ STT 일시정지됨")
    }
    
    // MARK: - RESUME
    func resumeTranscription() {
        guard !audioEngine.isRunning, isStarted else { return }
        do {
            try audioEngine.start()
            print("▶️ STT 재개됨")
        } catch {
            print("❌ STT 재개 오류:", error.localizedDescription)
        }
    }
    
    // MARK: - STOP
    func stopLiveTranscription() {
        cleanupResources()
        print("🛑 STT 완전 종료됨")
    }
    
    private func cleanupResources() {
        isStarted = false
        
        recognitionRequest?.endAudio()
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        transcriptContinuation?.finish()
        transcriptContinuation = nil
    }
}
