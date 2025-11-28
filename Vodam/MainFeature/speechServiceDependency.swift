//
//  SpeechServiceClient.swift
//  Vodam
//

import ComposableArchitecture
import Speech

struct SpeechServiceClient {
    var startLiveTranscription: @Sendable () -> AsyncStream<String>
    var stopLiveTranscription: @Sendable () -> Void
}

extension SpeechServiceClient: DependencyKey {
    static let liveValue: SpeechServiceClient = {
        let service = SpeechService()
        return SpeechServiceClient(
            startLiveTranscription: { service.startLiveTranscription() },
            stopLiveTranscription: { service.stopLiveTranscription() }
        )
    }()
    
    static let testValue = SpeechServiceClient(
        startLiveTranscription: { AsyncStream { _ in } },
        stopLiveTranscription: { }
    )
}

extension DependencyValues {
    var speechService: SpeechServiceClient {
        get { self[SpeechServiceClient.self] }
        set { self[SpeechServiceClient.self] = newValue }
    }
}
