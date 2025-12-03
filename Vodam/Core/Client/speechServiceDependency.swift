//
//  SpeechServiceClient.swift
//  Vodam
//

import ComposableArchitecture
import Speech

struct SpeechServiceClient {
    var startLiveTranscription: @Sendable (_ owner: String) async -> AsyncStream<String>?
    var stopLiveTranscription: @Sendable (_ owner: String) async -> Void
    var pauseTranscription: @Sendable (_ owner: String) async -> Void
    var resumeTranscription: @Sendable (_ owner: String) async -> Void
    var forceStop: @Sendable () async -> Void
}

extension SpeechServiceClient: DependencyKey {
    static let liveValue = SpeechServiceClient(
        startLiveTranscription: { owner in
            await SpeechService.shared.startLiveTranscription(owner: owner)
        },
        stopLiveTranscription: { owner in
            await SpeechService.shared.stopLiveTranscription(owner: owner)
        },
        pauseTranscription: { owner in
            await SpeechService.shared.pauseTranscription(owner: owner)
        },
        resumeTranscription: { owner in
            await SpeechService.shared.resumeTranscription(owner: owner)
        },
        forceStop: {
            await SpeechService.shared.forceStop()
        }
    )
    
    static let testValue = SpeechServiceClient(
        startLiveTranscription: { _ in AsyncStream { _ in } },
        stopLiveTranscription: { _ in },
        pauseTranscription: { _ in },
        resumeTranscription: { _ in },
        forceStop: { }
    )
}

extension DependencyValues {
    var speechService: SpeechServiceClient {
        get { self[SpeechServiceClient.self] }
        set { self[SpeechServiceClient.self] = newValue }
    }
}
