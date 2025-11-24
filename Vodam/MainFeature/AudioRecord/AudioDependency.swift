//
//  AudioDependency.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import ComposableArchitecture

enum AudioRecorderKey: DependencyKey {
    static let liveValue: AudioRecorderService = {
        let manager = AudioRecorderManager()

        return AudioRecorderService(
            startRecording: {
                try manager.start()
            },
            pauseRecording: {
                manager.pause()
            },
            resumeRecording: {
                manager.resume()
            },
            stopRecording: {
                manager.stop()
            }
        )
    }()
}

extension DependencyValues {
    var audioRecorder: AudioRecorderService {
        get { self[AudioRecorderKey.self] }
        set { self[AudioRecorderKey.self] = newValue }
    }
}
