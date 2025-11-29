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
    @Dependency(\.fileCloudClient) var fileCloudClient
    
    enum Status: Equatable {
        case ready
        case recording
        case paused
        case finishing
        
        var localizedText: String {
            switch self {
            case .ready: "녹음 준비"
            case .recording: "녹음 중"
            case .paused: "일시 정지"
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
        case syncCompleted(String)
        
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case projectSaved(String)
            case syncCompleted(String)
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
                    // ✅ 일시정지 → 재시작
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
                let saveProject = projectLocalDataClient.save
                let uploadAudio = fileCloudClient.uploadFile
                let uploadProjects = firebaseClient.uploadProjects
                let updateSyncStatus = projectLocalDataClient.updateSyncStatus
                
                return .run { send in
                    do {
                        // ✅ 1. 파일을 Documents로 복사
                        guard let storedPath = copyFileToDocuments(from: tempUrl) else {
                            await send(.recordingSaveFailed("파일 저장 실패"))
                            return
                        }
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy.MM.dd HH:mm"
                        let fileName = "녹음 \(dateFormatter.string(from: Date()))"
                        
                        // ✅ 2. SwiftData에 먼저 저장하여 ID 생성
                        let payload = try await MainActor.run {
                            try projectLocalDataClient.save(
                                context,
                                fileName,
                                .audio,
                                storedPath,
                                length,
                                nil,
                                ownerId
                            )
                        }
                        print("✅ 로컬 저장 완료: \(payload.id)")
                        
                        await send(.recordingSaved(payload.id))
                        
                        // ✅ 3. 로그인 사용자라면 Storage 업로드 (생성된 ID 사용)
                        if let ownerId {
                            do {
                                let localURL = URL(fileURLWithPath: storedPath)
                                
                                // 파일 존재 확인
                                let fileManager = FileManager.default
                                guard fileManager.fileExists(atPath: localURL.path) else {
                                    print("❌ 업로드할 파일이 존재하지 않음: \(localURL.path)")
                                    throw NSError(domain: "RecordingFeature", code: -1, userInfo: [NSLocalizedDescriptionKey: "업로드할 파일이 존재하지 않습니다"])
                                }
                                
                                print("📤 Storage 업로드 시작 (projectId: \(payload.id))")
                                let remotePath = try await fileCloudClient.uploadFile(
                                    ownerId,
                                    payload.id,  // ✅ 생성된 projectId 사용
                                    localURL
                                )
                                print("✅ Storage 업로드 완료: \(remotePath)")
                                
                                // ✅ 4. Firestore 업로드
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
                                print("☁️ Firebase DB 업로드 완료 (remoteAudioPath: \(remotePath))")
                                
                                // ✅ 5. 로컬 상태 업데이트
                                try await MainActor.run {
                                    try projectLocalDataClient.updateSyncStatus(
                                        context,
                                        [payload.id],
                                        .synced,
                                        ownerId,
                                        remotePath
                                    )
                                }
                                print("✅ 동기화 상태 업데이트 완료")
                                
                                // 동기화 완료 알림
                                await send(.syncCompleted(payload.id))
                                
                            } catch {
                                print("❌ 클라우드 동기화 실패 (로컬 저장은 완료): \(error.localizedDescription)")
                                // 로컬 저장은 이미 완료되었으므로 에러는 로그만 남김
                            }
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
                
            case .syncCompleted(let projectId):
                return .send(.delegate(.syncCompleted(projectId)))
                
            case .recordingSaveFailed(let error):
                print("❌ 녹음 저장 실패: \(error)")
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
    
    private func copyFileToDocuments(from url: URL) -> String? {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let destinationURL = documentsDir.appendingPathComponent(url.lastPathComponent)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        
        do {
            try fileManager.copyItem(at: url, to: destinationURL)
            print("✅ 파일 복사 완료: \(destinationURL.path)")
            return destinationURL.path
        } catch {
            print("❌ 파일 이동 실패: \(error)")
            return nil
        }
    }
}
