import Foundation
import Speech
import AVFoundation
import Combine


class SpeechRecognizer: NSObject, ObservableObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko_KR"))!
    private var audioEngine = AVAudioEngine()
    private var request = SFSpeechAudioBufferRecognitionRequest()
    private var task: SFSpeechRecognitionTask?

    @Published var text: String = ""

    func start() {
        SFSpeechRecognizer.requestAuthorization { auth in
            guard auth == .authorized else { return }
            DispatchQueue.main.async {
                self.startRecording()
            }
        }
    }

    func stop() {
        task?.finish()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func startRecording() {
        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)

        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        task = recognizer.recognitionTask(with: request) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.text = result.bestTranscription.formattedString
                }
            }
        }
    }
}
