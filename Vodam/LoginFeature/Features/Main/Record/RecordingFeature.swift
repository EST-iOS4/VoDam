//
//  RecordingFeature.swift
//  VoDam
//

import ComposableArchitecture
import Foundation

@Reducer
struct RecordingFeature {

    // MARK: - 녹음 상태
    enum Status: Equatable {
        case ready
        case recording
        case paused

        var localizedText: String {
            switch self {
            case .ready: "준비됨"
            case .recording: "녹음 중"
            case .paused: "일시정지"
            }
        }
    }

    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var status: Status = .ready
        var elapsedSeconds: Int = 0          // 화면에 보여줄 타이머
        var fileURL: URL? = nil              // 마지막으로 녹음된 파일 URL
        var lastRecordedLength: Int = 0      // 마지막 녹음 길이(초) - SwiftData 저장용
    }

    // MARK: - Action
    enum Action: Equatable {
        case startTapped
        case pauseTapped
        case stopTapped
        case tick
    }

    // MARK: - Dependencies
    @Dependency(\.audioRecorder) var recorder
    @Dependency(\.continuousClock) var clock

    // MARK: - Reducer
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            // MARK: - 시작
            case .startTapped:
                if state.status == .ready {
                    state.elapsedSeconds = 0
                }
                state.status = .recording

                return .run { send in
                    do {
                        let url = try recorder.startRecording()
                        print("🎙 녹음 시작됨 → \(url)")
                    } catch {
                        print("❌ 녹음 시작 실패: \(error)")
                    }

                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.tick)
                    }
                }
                .cancellable(id: "recording_timer", cancelInFlight: true)

            // MARK: - 일시정지
            case .pauseTapped:
                guard state.status == .recording else { return .none }
                recorder.pauseRecording()
                state.status = .paused

                return .cancel(id: "recording_timer")

            // MARK: - 정지
            case .stopTapped:
                let url = recorder.stopRecording()
                state.fileURL = url                // 🔥 View에서 onChange로 감지
                state.lastRecordedLength = state.elapsedSeconds

                state.status = .ready
                state.elapsedSeconds = 0

                return .cancel(id: "recording_timer")

            // MARK: - tick
            case .tick:
                if state.status == .recording {
                    state.elapsedSeconds += 1
                }
                return .none
            }
        }
    }
}
