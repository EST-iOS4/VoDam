//
//  RecordingFeature.swift
//

import ComposableArchitecture
import Foundation

@Reducer
struct RecordingFeature {
    
    @Dependency(\.audioRecorder) var recorder
    @Dependency(\.continuousClock) var clock
    @Dependency(\.speechService) var speechService
    
    enum Status: Equatable {
        case ready
        case recording
        case paused
        
        var localizedText: String {
            switch self {
            case .ready: "준비됨"
            case .recording: "녹음 중입니다"
            case .paused: "일시정지됨"
            }
        }
    }
    
    @ObservableState
    struct State: Equatable {
        var status: Status = .ready
        var elapsedSeconds: Int = 0
        var fileURL: URL? = nil
        var lastRecordedLength: Int = 0
    }
    
    enum Action: Equatable {
        case startTapped
        case pauseTapped
        case stopTapped
        case tick
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
            case .startTapped:
                let wasReady = state.status == .ready
                if wasReady {
                    state.elapsedSeconds = 0
                }
                state.status = .recording
                
                return .merge(
                    .run { _ in
                        if wasReady {
                            try recorder.startRecording()
                        } else {
                            recorder.resumeRecording()
                        }
                        speechService.startLiveTranscription()
                    }
                    .cancellable(id: "stt_stream", cancelInFlight: true),
                    
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.tick)
                        }
                    }
                    .cancellable(id: "recording_timer", cancelInFlight: true)
                )
                
            case .pauseTapped:
                guard state.status == .recording else { return .none }
                recorder.pauseRecording()
                state.status = .paused
                
                return .merge(
                    .cancel(id: "recording_timer"),
                    .run { _ in speechService.stopLiveTranscription() }
                )

            case .stopTapped:
                let url = recorder.stopRecording()
                let length = state.elapsedSeconds
                state.fileURL = url
                state.lastRecordedLength = length
                state.status = .ready
                state.elapsedSeconds = 0

                return .merge(
                    .cancel(id: "recording_timer"),
                    .run { _ in
                        speechService.stopLiveTranscription()
                    }
                )
                
            case .tick:
                if state.status == .recording {
                    state.elapsedSeconds += 1
                }
                return .none
            }
        }
    }
}
