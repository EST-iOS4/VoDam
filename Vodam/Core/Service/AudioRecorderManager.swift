//
//  AudioRecorderManager.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import AVFoundation
import Foundation

final class AudioRecorderManager: NSObject {
    private var recorder: AVAudioRecorder?
    private(set) var currentURL: URL?     // 녹음 파일 URL 저장

    // MARK: - 녹음 시작
    func start() throws -> URL {
        // 1. 녹음 파일 이름 설정
        let filename = "\(UUID().uuidString).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        currentURL = url

        // 2. 녹음 설정값(AAC, 44.1kHz, 모노, 하이퀄리티)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // 3. AVAudioRecorder 생성 및 녹음 시작
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.prepareToRecord()
        recorder?.record()

        return url
    }

    // MARK: - 일시정지
    func pause() {
        recorder?.pause()
    }

    // MARK: - 재개
    func resume() {
        recorder?.record()
    }

    // MARK: - 정지
    func stop() -> URL? {
        recorder?.stop()
        return currentURL
    }
}
