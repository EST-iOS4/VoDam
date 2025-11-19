//
//  RecordingFeature.swift
//  VoDam
//
//  Created by 강지원 on 11/18/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct RecordingFeature {
    
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
    
    @ObservableState
    struct State: Equatable {
        var status: Status = .ready
        var elapsedSeconds: Int = 0
        var fileURL: URL? = nil          // 녹음 파일 URL
    }
    
    enum Action: Equatable {
        case startTapped
        case pauseTapped
        case stopTapped
        case tick
    }
    
    @Dependency(\.audioRecorder) var recorder
    @Dependency(\.continuousClock) var clock
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
                // MARK: - 시작
            case .startTapped:
                if state.status == .ready {
                    state.elapsedSeconds = 0
                }
                state.status = .recording
                
                print("🎙 녹음 시작됨")
                
                return .run { send in
                    let url = try recorder.startRecording()
                    print("📁 녹음 파일 생성 위치: \(url)")
                    
                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.tick)
                    }
                }
                .cancellable(id: "recording_timer", cancelInFlight: true)
                
                // MARK: - 일시정지
            case .pauseTapped:
                guard state.status == .recording else { return .none }
                state.status = .paused
                
                recorder.pauseRecording()
                print("⏸ 녹음 일시정지됨")
                
                return .cancel(id: "recording_timer")
                
                // MARK: - 정지
            case .stopTapped:
                state.status = .ready
                let url = recorder.stopRecording()
                state.fileURL = url
                state.elapsedSeconds = 0
                
                print("⏹ 녹음 정지됨")
                if let url = url {
                    print("💾 녹음 저장 완료: \(url)")
                } else {
                    print("⚠️ 녹음 저장 실패: URL 없음")
                }
                
                return .cancel(id: "recording_timer")
                
                // MARK: - tick
            case .tick:
                if state.status == .recording {
                    state.elapsedSeconds += 1
                    print("⏱ 녹음 시간: \(state.elapsedSeconds)초")
                }
                return .none
            }
        }
    }
}
