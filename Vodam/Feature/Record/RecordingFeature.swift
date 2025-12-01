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
        case finishing  // ✅ 추가
        
        var localizedText: String {
            switch self {
            case .ready: "녹음 준비"
            case .recording: "녹음 중"
            case .paused: "일시 정지"
            case .finishing: "저장 중..."  // ✅ 추가
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
        
        // ✅ 추가
        var liveTranscript: String = ""
        var finalTranscript: String? = nil
    }
    
    enum Action: Equatable {
        case startTapped
        case pauseTapped
        case stopTapped
        case tick
        
        // ✅ 추가
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
                
            case .startTapped:
                switch state.status {
                case .ready:
                    // ✅ 수정: transcript 초기화 및 STT 스트림 수신
                    state.elapsedSeconds = 0
                    state.liveTranscript = ""
                    state.finalTranscript = nil
                    state.status = .recording
                    
                    let startLiveTranscription = speechService.startLiveTranscription
                    
                    return .merge(
                        .run { _ in _ = try? recorder.startRecording() },
                        .run { send in
                            let stream = startLiveTranscription()
                            for await transcript in stream {
                                await send(.liveTranscriptUpdated(transcript))
                            }
                            await send(.liveTranscriptFinished)
                        }
                        .cancellable(id: CancelID.liveSTT, cancelInFlight: true),
                        .run { send in
                            for await _ in clock.timer(interval: .seconds(1)) { await send(.tick) }
                        }.cancellable(id: CancelID.timer, cancelInFlight: true)
                    )
                    
                case .paused:
                    // ✅ 수정: resumeTranscription 사용
                    state.status = .recording
                    
                    let resumeTranscription = speechService.resumeTranscription
                    
                    return .merge(
                        .run { _ in recorder.resumeRecording() },
                        .run { _ in resumeTranscription() },
                        .run { send in
                            for await _ in clock.timer(interval: .seconds(1)) { await send(.tick) }
                        }.cancellable(id: CancelID.timer, cancelInFlight: true)
                    )
                    
                case .recording, .finishing:
                    return .none
                }
                
            case .pauseTapped:
                guard state.status == .recording else { return .none }
                recorder.pauseRecording()
                state.status = .paused
                
                // ✅ 수정: pauseTranscription 사용
                let pauseTranscription = speechService.pauseTranscription
                
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in pauseTranscription() }
                )
                
            case .stopTapped:
                // ✅ 수정: finishing 상태 추가
                guard state.status == .recording || state.status == .paused else { return .none }
                
                let url = recorder.stopRecording()
                state.fileURL = url
                state.lastRecordedLength = state.elapsedSeconds
                state.elapsedSeconds = 0
                state.status = .finishing
                
                let stopLiveTranscription = speechService.stopLiveTranscription
                
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in stopLiveTranscription() }
                )
                
            case .tick:
                if state.status == .recording { state.elapsedSeconds += 1 }
                return .none
                
            // ✅ 추가: STT 결과 처리
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
                
            case .saveRecording(let tempUrl, let length, let ownerId, let context):
                // ✅ 수정: finalTranscript 사용
                let transcript = state.finalTranscript
                
                return .run { [projectLocalDataClient, fileCloudClient, firebaseClient] send in
                    do {
                        guard let storedPath = copyFileToDocuments(from: tempUrl) else {
                            await send(.recordingSaveFailed("파일 저장 실패"))
                            return
                        }
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy.MM.dd HH:mm"
                        let fileName = "녹음 \(dateFormatter.string(from: Date()))"
                        
                        let payload = try await MainActor.run {
                            try projectLocalDataClient.save(
                                context,
                                fileName,
                                .audio,
                                storedPath,
                                length,
                                transcript,  // ✅ 수정: nil → transcript
                                ownerId
                            )
                        }
                        print("✅ 로컬 저장 완료: \(payload.id), transcript: \(transcript ?? "없음")")
                        
                        await send(.recordingSaved(payload.id))
                        
                        if let ownerId {
                            do {
                                let localURL = URL(fileURLWithPath: storedPath)
                                
                                let fileManager = FileManager.default
                                guard fileManager.fileExists(atPath: localURL.path) else {
                                    print("❌ 업로드할 파일이 존재하지 않음: \(localURL.path)")
                                    throw NSError(domain: "RecordingFeature", code: -1, userInfo: [NSLocalizedDescriptionKey: "업로드할 파일이 존재하지 않습니다"])
                                }
                                
                                print("📤 Storage 업로드 시작 (projectId: \(payload.id))")
                                let remotePath = try await fileCloudClient.uploadFile(
                                    ownerId,
                                    payload.id,
                                    localURL
                                )
                                print("✅ Storage 업로드 완료: \(remotePath)")
                                
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
                                
                                await send(.syncCompleted(payload.id))
                                
                            } catch {
                                print("❌ 클라우드 동기화 실패 (로컬 저장은 완료): \(error.localizedDescription)")
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
                // ✅ 추가: transcript 초기화
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
