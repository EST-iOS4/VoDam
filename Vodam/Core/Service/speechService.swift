import Speech
import AVFoundation

actor SpeechService {
    
    static let shared = SpeechService()
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    
    private var transcriptContinuation: AsyncStream<String>.Continuation?
    private var isStarted = false
    private var currentOwner: String?
    
    private init() {
        Task {
            requestAuthorization()
        }
    }
    
    private nonisolated func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                print("STT 사용 허가됨")
            default:
                print("STT 권한 거부됨")
            }
        }
    }
    
    // MARK: - START
    func startLiveTranscription(owner: String) -> AsyncStream<String>? {
        if isStarted {
            print("기존 세션 정리 중... (owner: \(currentOwner ?? "unknown"))")
            stopLiveTranscriptionSync()
        }
        
        isStarted = true
        currentOwner = owner
        
        return AsyncStream { continuation in
            self.transcriptContinuation = continuation
            
            Task { @MainActor in
                await self.setupTranscriptionOnMain()
            }
        }
    }
    
    @MainActor
    private func setupTranscriptionOnMain() async {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioSession 오류:", error)
            await finishStream()
            return
        }
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else {
            print("하드웨어 포맷 무효")
            await finishStream()
            return
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { buffer, _ in
            request.append(buffer)
        }
        
        await self.updateEngineAndRequest(engine: engine, request: request)
        
        guard let recognizer = self.recognizer else {
            print("Recognizer 없음")
            await finishStream()
            return
        }
        
        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            Task {
                await self.handleRecognitionResult(result: result, error: error)
            }
        }
        
        await self.updateTask(task)
        
        do {
            engine.prepare()
            try engine.start()
            let owner = await self.currentOwner
            print("실시간 STT 시작됨 (owner: \(owner ?? "unknown"))")
        } catch {
            print("STT Start 오류:", error)
            await finishStream()
        }
    }
    
    private func updateEngineAndRequest(engine: AVAudioEngine, request: SFSpeechAudioBufferRecognitionRequest) {
        self.audioEngine = engine
        self.recognitionRequest = request
    }
    
    private func updateTask(_ task: SFSpeechRecognitionTask) {
        self.recognitionTask = task
    }
    
    private func finishStream() {
        transcriptContinuation?.finish()
        transcriptContinuation = nil
        isStarted = false
        currentOwner = nil
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result = result {
            transcriptContinuation?.yield(result.bestTranscription.formattedString)
            
            if result.isFinal {
                transcriptContinuation?.finish()
            }
        }
        
        if let error = error {
            let nsError = error as NSError
            guard nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 216 else { return }
            print("STT 오류:", error.localizedDescription)
            transcriptContinuation?.finish()
        }
    }
    
    // MARK: - PAUSE
    func pauseTranscription(owner: String) {
        guard currentOwner == owner else {
            print("다른 owner가 pause 시도: \(owner), 현재: \(currentOwner ?? "none")")
            return
        }
        guard let engine = audioEngine, engine.isRunning else { return }
        engine.pause()
        print("STT 일시정지됨")
    }
    
    // MARK: - RESUME
    func resumeTranscription(owner: String) {
        guard currentOwner == owner else {
            print("다른 owner가 resume 시도: \(owner), 현재: \(currentOwner ?? "none")")
            return
        }
        guard let engine = audioEngine, !engine.isRunning, isStarted else { return }
        do {
            try engine.start()
            print("STT 재개됨")
        } catch {
            print("STT 재개 오류:", error.localizedDescription)
        }
    }
    
    // MARK: - STOP
    func stopLiveTranscription(owner: String) {
        guard currentOwner == owner || currentOwner == nil else {
            print("다른 owner가 stop 시도: \(owner), 현재: \(currentOwner ?? "none")")
            return
        }
        stopLiveTranscriptionSync()
    }
    
    func forceStop() {
        stopLiveTranscriptionSync()
    }
    
    private func stopLiveTranscriptionSync() {
        isStarted = false
        
        transcriptContinuation?.finish()
        transcriptContinuation = nil
        
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            if engine.isRunning {
                engine.stop()
            }
        }
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        DispatchQueue.global(qos: .background).async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        
        print("STT 완전 종료됨 (owner: \(currentOwner ?? "unknown"))")
        currentOwner = nil
    }
}
