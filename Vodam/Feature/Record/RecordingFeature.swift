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
        case finishing  // ✅ STT 완료 대기 상태 추가
        
        var localizedText: String {
            switch self {
            case .ready: "준비됨"
            case .recording: "녹음 중입니다"
            case .paused: "일시정지됨"
            case .finishing: "저장 중..."
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
        
        // ✅ Live STT 결과
        var liveTranscript: String = ""
        
        // ✅ 최종 transcript (녹음 완료 시 저장용)
        var finalTranscript: String? = nil
    }
    
    enum Action: Equatable {
        case startTapped
        case pauseTapped
        case stopTapped
        case tick
        
        case liveTranscriptUpdated(String)
        
        case liveTranscriptFinished
        
        case saveRecording(URL, Int, String?)
        case recordingSaved(String)
        case recordingSaveFailed(String)
        
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case projectSaved(String)
        }
    }
    
    nonisolated private enum CancelID {
        case timer
        case liveSTT
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
            case .startTapped:
                switch state.status {
                case .ready:
                    state.elapsedSeconds = 0
                    state.liveTranscript = ""
                    state.finalTranscript = nil
                    state.status = .recording
                    
                    let startLiveTranscription = speechService.startLiveTranscription
                    
                    return .merge(
                        // Start recording
                        .run { _ in
                            _ = try? recorder.startRecording()
                        }
                        .cancellable(id: CancelID.liveSTT, cancelInFlight: true),
                        
                        // Live STT stream
                        .run { send in
                            let stream = startLiveTranscription()
                            for await transcript in stream {
                                await send(.liveTranscriptUpdated(transcript))
                            }
                            // ✅ 스트림 종료 시 알림
                            await send(.liveTranscriptFinished)
                        }
                        .cancellable(id: CancelID.liveSTT, cancelInFlight: true),
                        
                        // Tick timer
                        .run { send in
                            for await _ in clock.timer(interval: .seconds(1)) {
                                await send(.tick)
                            }
                        }
                        .cancellable(id: CancelID.timer, cancelInFlight: true)
                    )
                    
                case .paused:
                    state.status = .recording
                    
                    let startLiveTranscription = speechService.startLiveTranscription
                    
                    return .merge(
                        // Resume recording
                        .run { _ in
                            recorder.resumeRecording()
                        }
                        .cancellable(id: CancelID.liveSTT, cancelInFlight: true),
                        
                        // Live STT stream
                        .run { send in
                            let stream = startLiveTranscription()
                            for await transcript in stream {
                                await send(.liveTranscriptUpdated(transcript))
                            }
                            await send(.liveTranscriptFinished)
                        }
                        .cancellable(id: CancelID.liveSTT, cancelInFlight: true),
                        
                        // Tick timer
                        .run { send in
                            for await _ in clock.timer(interval: .seconds(1)) {
                                await send(.tick)
                            }
                        }
                        .cancellable(id: CancelID.timer, cancelInFlight: true)
                    )
                    
                default:
                    // state.status == .recording or .finishing
                    return .none
                }
                
            case .pauseTapped:
                guard state.status == .recording else { return .none }
                recorder.pauseRecording()
                state.status = .paused
                
                let stopLiveTranscription = speechService.stopLiveTranscription
                
                return .merge(
                    .cancel(id: CancelID.timer),
                    .cancel(id: CancelID.liveSTT),
                    .run { _ in
                        stopLiveTranscription()
                    }
                )
                
            case .stopTapped:
                guard state.status == .recording || state.status == .paused else { return .none }
                
                let url = recorder.stopRecording()
                let length = state.elapsedSeconds
                state.fileURL = url
                state.lastRecordedLength = state.elapsedSeconds
                state.elapsedSeconds = 0
                state.status = .finishing  // ✅ STT 완료 대기
                
                let stopLiveTranscription = speechService.stopLiveTranscription
                
                return .merge(
                    .cancel(id: CancelID.timer),
                    // ✅ liveSTT는 cancel하지 않음 - 자연스럽게 종료되도록 함
                    .run { _ in
                        stopLiveTranscription()
                    }
                )
                
            case .tick:
                if state.status == .recording {
                    state.elapsedSeconds += 1
                }
                return .none
                
            case .liveTranscriptUpdated(let transcript):
                // ✅ 빈 문자열은 무시
                guard !transcript.isEmpty else { return .none }
                state.liveTranscript = transcript
                return .none
                
            // ✅ STT 스트림 종료 후 최종 저장
            case .liveTranscriptFinished:
                guard state.status == .finishing else { return .none }
                
                state.finalTranscript = state.liveTranscript.isEmpty ? nil : state.liveTranscript
                state.status = .ready
                
                print("🏁 STT 완료, 최종 transcript: \(state.finalTranscript ?? "없음")")
                return .none
                
            case .saveRecording:
                return .none
                
            case .recordingSaved(let projectId):
                state.savedProjectId = projectId
                state.fileURL = nil
                state.liveTranscript = ""
                state.finalTranscript = nil
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
