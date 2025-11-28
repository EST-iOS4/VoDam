//
//  RecordingFeature.swift
//

import ComposableArchitecture
import Foundation
import SwiftData // ModelContext 사용을 위해 필요

@Reducer
struct RecordingFeature {
    
    @Dependency(\.audioRecorder) var recorder
    @Dependency(\.continuousClock) var clock
    @Dependency(\.speechService) var speechService
    
    // 저장/업로드에 필요한 클라이언트 모두 추가
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient
    @Dependency(\.audioCloudClient) var audioCloudClient
    
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
        
        // ModelContext를 받아서 저장 처리
        case saveRecording(URL, Int, String?, ModelContext)
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
                switch state.status {
                case .ready:
                    state.elapsedSeconds = 0
                    state.status = .recording
                    return .merge(
                        .run { _ in _ = try? recorder.startRecording() },
                        .run { _ in speechService.startLiveTranscription() }
                            .cancellable(id: "stt_stream", cancelInFlight: true),
                        .run { send in
                            for await _ in clock.timer(interval: .seconds(1)) { await send(.tick) }
                        }.cancellable(id: "recording_timer", cancelInFlight: true)
                    )
                    
                case .paused:
                    state.status = .recording
                    return .merge(
                        .run { _ in recorder.resumeRecording() },
                        .run { _ in speechService.startLiveTranscription() }
                            .cancellable(id: "stt_stream", cancelInFlight: true),
                        .run { send in
                            for await _ in clock.timer(interval: .seconds(1)) { await send(.tick) }
                        }.cancellable(id: "recording_timer", cancelInFlight: true)
                    )
                case .recording:
                    return .none
                }
                
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
                if state.status == .recording { state.elapsedSeconds += 1 }
                return .none
                
            // 저장 로직 통합 구현
            case .saveRecording(let tempUrl, let length, let ownerId, let context):
                return .run { [projectLocalDataClient, audioCloudClient, firebaseClient] send in
                    do {
                        // 1. 파일 이동 (Temp -> Documents)
                        guard let storedPath = copyFileToDocuments(from: tempUrl) else {
                            await send(.recordingSaveFailed("파일 저장 실패"))
                            return
                        }
                        
                        // 2. 파일 이름 생성
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy.MM.dd HH:mm"
                        let fileName = "녹음 \(dateFormatter.string(from: Date()))"
                        
                        // 3. SwiftData에 저장 (Local)
                        let payload = try projectLocalDataClient.save(
                            context,
                            fileName,
                            .audio,
                            storedPath,
                            length,
                            nil,
                            ownerId // 비회원이면 nil
                        )
                        print("로컬 저장 완료: \(payload.id)")
                        
                        // 성공 알림 (UI 갱신용)
                        await send(.recordingSaved(payload.id))
                        
                        // 4. 로그인 유저라면 클라우드 업로드 진행
                        if let ownerId {
                            let localURL = URL(fileURLWithPath: storedPath)
                            
                            // 4-1. Audio Storage 업로드
                            let remotePath = try await audioCloudClient.uploadAudio(
                                ownerId,
                                payload.id,
                                localURL
                            )
                            
                            // 4-2. Firebase DB 업로드용 페이로드 생성
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
                                syncStatus: .synced, // 동기화됨 상태
                                remoteAudioPath: remotePath
                            )
                            
                            // 4-3. Firebase DB 업로드
                            try await firebaseClient.uploadProjects(ownerId, [syncedPayload])
                            
                            // 4-4. 로컬 DB 상태 업데이트
                            await MainActor.run {
                                try? projectLocalDataClient.updateSyncStatus(
                                    context,
                                    [payload.id],
                                    .synced,
                                    ownerId,
                                    remotePath
                                )
                            }
                            print("클라우드 동기화 완료")
                        } else {
                            print("비회원 모드: 클라우드 업로드 생략")
                        }
                        
                    } catch {
                        print("저장 프로세스 실패: \(error)")
                        await send(.recordingSaveFailed(error.localizedDescription))
                    }
                }
                
            case .recordingSaved(let projectId):
                state.savedProjectId = projectId
                state.fileURL = nil
                return .send(.delegate(.projectSaved(projectId)))
                
            case .recordingSaveFailed(let error):
                print("녹음 저장 실패 에러: \(error)")
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
    
    // MARK: - Helper (파일 이동 로직)
    private func copyFileToDocuments(from url: URL) -> String? {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let destinationURL = documentsDir.appendingPathComponent(url.lastPathComponent)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        
        do {
            try fileManager.copyItem(at: url, to: destinationURL)
            return destinationURL.path
        } catch {
            print("파일 이동 실패: \(error)")
            return nil
        }
    }
}
