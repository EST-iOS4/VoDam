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

        var savedProjectId: String? = nil
    }

    enum Action: Equatable {
        case startTapped
        case pauseTapped
        case stopTapped
        case tick

        case saveRecording(URL, Int, String?)
        case recordingSaved(String)
        case recordingSaveFailed(String)

        case delegate(Delegate)

        enum Delegate: Equatable {
            case projectSaved(String)
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            case .startTapped:
                if state.status == .ready {
                    state.elapsedSeconds = 0
                }
                state.status = .recording

                return .merge(
                    .run { _ in speechService.startLiveTranscription() }
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
                state.fileURL = url
                state.lastRecordedLength = state.elapsedSeconds
                state.status = .ready
                state.elapsedSeconds = 0

                return .merge(
                    .cancel(id: "recording_timer"),
                    .run { _ in speechService.stopLiveTranscription() }
                )

            case .tick:
                if state.status == .recording {
                    state.elapsedSeconds += 1
                }
                return .none

            case .saveRecording(let url, let length, let ownerId):
                return .none

            case .recordingSaved(let projectId):
                state.savedProjectId = projectId
                state.fileURL = nil
                return .send(.delegate(.projectSaved(projectId)))

            case .recordingSaveFailed(let error):
                print("녹음 저장 실패: \(error)")
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
