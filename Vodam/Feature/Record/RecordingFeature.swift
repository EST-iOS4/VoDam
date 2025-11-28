//
//  RecordingFeature.swift
//

import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct RecordingFeature {
    
    @Dependency(\.audioRecorder) var recorder
    @Dependency(\.continuousClock) var clock
    @Dependency(\.speechService) var speechService
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient
    @Dependency(\.audioCloudClient) var audioCloudClient
    
    enum Status: Equatable {
        case ready
        case recording
        case paused
        case finishing
        
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
        
        var liveTranscript: String = ""
        var finalTranscript: String? = nil
    }
    
    enum Action: Equatable {
        case startTapped
        case pauseTapped
        case stopTapped
        case tick
        
        case liveTranscriptUpdated(String)
        case liveTranscriptFinished
        
        case saveRecording(URL, Int, String?, ModelContext)
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
                
            // MARK: - Start
            case .startTapped:
                switch state.status {
                case .ready:
                    // ✅ 최초 시작: 녹음 + STT + 타이머 모두 시작
                    state.elapsedSeconds = 0
                    state.liveTranscript = ""
                    state.finalTranscript = nil
                    state.status = .recording
                    
                    let startLiveTranscription = speechService.startLiveTranscription
                    
                    return .merge(
                        .run { _ in
                            _ = try? recorder.startRecording()
                        },
                        .run { send in
                            let stream = startLiveTranscription()
                            for await transcript in stream {
                                await send(.liveTranscriptUpdated(transcript))
                            }
                            await send(.liveTranscriptFinished)
                        }
                        .cancellable(id: CancelID.liveSTT, cancelInFlight: true),
                        .run { send in
                            for await _ in clock.timer(interval: .seconds(1)) {
                                await send(.tick)
                            }
                        }
                        .cancellable(id: CancelID.timer, cancelInFlight: true)
                    )
                    
                case .paused:
                    // ✅ 일시정지 → 재시작:
                    //    - 녹음 resume
                    //    - STT는 새로 시작 ❌, 기존 세션 resume ✅
                    state.status = .recording
                    
                    let resumeTranscription = speechService.resumeTranscription
                    
                    return .merge(
                        .run { _ in
                            recorder.resumeRecording()
                        },
                        .run { _ in
                            resumeTranscription()
                        },
                        .run { send in
                            for await _ in clock.timer(interval: .seconds(1)) {
                                await send(.tick)
                            }
                        }
                        .cancellable(id: CancelID.timer, cancelInFlight: true)
                    )
                    
                case .recording, .finishing:
                    return .none
                }
                
            // MARK: - Pause
            case .pauseTapped:
                guard state.status == .recording else { return .none }
                recorder.pauseRecording()
                state.status = .paused
                
                let pauseTranscription = speechService.pauseTranscription
                
                // ✅ STT 스트림(liveSTT)은 cancel 하지 않음
                //    -> 같은 AsyncStream 안에서 audioEngine 만 pause
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in
                        pauseTranscription()
                    }
                )
                
            // MARK: - Stop
            case .stopTapped:
                guard state.status == .recording || state.status == .paused else { return .none }
                
                let url = recorder.stopRecording()
                state.fileURL = url
                state.lastRecordedLength = state.elapsedSeconds
                state.elapsedSeconds = 0
                state.status = .finishing
                
                let stopLiveTranscription = speechService.stopLiveTranscription
                
                return .merge(
                    .cancel(id: CancelID.timer),
                    // 필요하면 여기서 liveSTT 취소도 추가 가능하지만,
                    // stopLiveTranscription() 에서 continuation.finish() 해주면
                    // stream 종료 → .liveTranscriptFinished 액션까지 흐름 이어짐
                    .run { _ in
                        stopLiveTranscription()
                    }
                )
                
            // MARK: - Tick
            case .tick:
                if state.status == .recording {
                    state.elapsedSeconds += 1
                }
                return .none
                
            // MARK: - STT Updates
            case .liveTranscriptUpdated(let transcript):
                guard !transcript.isEmpty else { return .none }
                state.liveTranscript = transcript
                return .none
                
            case .liveTranscriptFinished:
                guard state.status == .finishing else { return .none }
                state.finalTranscript = state.liveTranscript.isEmpty ? nil : state.liveTranscript
                state.status = .ready
                print("🏁 STT 완료, 최종 transcript: \(state.finalTranscript ?? "없음")")
                return .none
                
            // MARK: - Save
            case .saveRecording(let tempUrl, let length, let ownerId, let context):
                let transcript = state.finalTranscript
                
                return .run { [projectLocalDataClient, audioCloudClient, firebaseClient] send in
                    do {
                        guard let storedPath = copyFileToDocuments(from: tempUrl) else {
                            await send(.recordingSaveFailed("파일 저장 실패"))
                            return
                        }
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy.MM.dd HH:mm"
                        let fileName = "녹음 \(dateFormatter.string(from: Date()))"
                        
                        let payload = try projectLocalDataClient.save(
                            context,
                            fileName,
                            .audio,
                            storedPath,
                            length,
                            transcript,
                            ownerId
                        )
                        print("✅ 로컬 저장 완료: \(payload.id), transcript: \(transcript ?? "없음")")
                        
                        await send(.recordingSaved(payload.id))
                        
                        if let ownerId {
                            let localURL = URL(fileURLWithPath: storedPath)
                            
                            let remotePath = try await audioCloudClient.uploadAudio(
                                ownerId,
                                payload.id,
                                localURL
                            )
                            
                            let syncedPayload = ProjectPayload(
                                id: payload.id,
                                name: payload.name,
                                creationDate: payload.creationDate,
                                category: payload.category,
                                isFavorite: payload.isFavorite,
                                filePath: payload.filePath,
                                fileLength: payload.fileLength,
                                transcript: payload.transcript,
                                ownerId: ownerId,
                                syncStatus: .synced,
                                remoteAudioPath: remotePath
                            )
                            
                            try await firebaseClient.uploadProjects(ownerId, [syncedPayload])
                            
                            await MainActor.run {
                                try? projectLocalDataClient.updateSyncStatus(
                                    context,
                                    [payload.id],
                                    .synced,
                                    ownerId,
                                    remotePath
                                )
                            }
                            print("✅ 클라우드 동기화 완료")
                        } else {
                            print("비회원 모드: 클라우드 업로드 생략")
                        }
                        
                    } catch {
                        print("❌ 저장 프로세스 실패: \(error)")
                        await send(.recordingSaveFailed(error.localizedDescription))
                    }
                }
                
            case .recordingSaved(let projectId):
                state.savedProjectId = projectId
                state.fileURL = nil
                state.liveTranscript = ""
                state.finalTranscript = nil
                return .send(.delegate(.projectSaved(projectId)))
                
            case .recordingSaveFailed(let error):
                print("녹음 저장 실패 에러: \(error)")
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Helper
private func copyFileToDocuments(from url: URL) -> String? {
    let fileManager = FileManager.default
    guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
    
    let destinationURL = documentsDir.appendingPathComponent(url.lastPathComponent)
    
    if fileManager.fileExists(atPath: destinationURL.path) {
        try? fileManager.removeItem(at: destinationURL)
    }
    
    do {
        try fileManager.copyItem(at: url, to: destinationURL)
        print("녹음 파일 복사 성공 → \(destinationURL.path)")
        return destinationURL.path
    } catch {
        print("파일 이동 실패: \(error)")
        return nil
    }
}
