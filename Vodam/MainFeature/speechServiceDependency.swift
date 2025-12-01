//
//  SpeechServiceClient.swift
//  Vodam
//

import ComposableArchitecture
import Speech

struct SpeechServiceClient {
    var startLiveTranscription: @Sendable () -> AsyncStream<String>
    var stopLiveTranscription: @Sendable () -> Void
    var pauseTranscription: @Sendable () -> Void
    var resumeTranscription: @Sendable () -> Void
}

extension SpeechServiceClient: DependencyKey {
    static let liveValue: SpeechServiceClient = {
        // 🔥 실제 SpeechService 인스턴스
        let service = SpeechService()
        
        return SpeechServiceClient(
            startLiveTranscription: { service.startLiveTranscription() },
            stopLiveTranscription: { service.stopLiveTranscription() },
            pauseTranscription: { service.pauseTranscription() },
            resumeTranscription: { service.resumeTranscription() }
        )
    }()
    
    static let testValue = SpeechServiceClient(
        startLiveTranscription: { AsyncStream { _ in } },
        stopLiveTranscription: { },
        pauseTranscription: { },
        resumeTranscription: { }
    )
}

extension DependencyValues {
    var speechService: SpeechServiceClient {
        get { self[SpeechServiceClient.self] }
        set { self[SpeechServiceClient.self] = newValue }
    }
}
