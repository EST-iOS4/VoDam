//
//  RecordingFeature.swift
//

import ComposableArchitecture
import Foundation
import SwiftData
import AVFoundation

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
        case recordingFileSaved(URL)  // ✅ 새로운 액션 추가
        
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
                    state.elapsedSeconds = 0
                    state.liveTranscript = ""
                    state.finalTranscript = nil
                    state.status = .recording
                    
                    let startLiveTranscription = speechService.startLiveTranscription
                    
                    return .merge(
                        
                        .run { _ in _ = try? await recorder.startRecording() },
                        .run { send in
                            // ✅ 녹음 시작 전 AVAudioSession 초기화
                            do {
                                let session = AVAudioSession.sharedInstance()
                                
                                // 기존 세션 비활성화
                                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                                
                                // 녹음 모드로 설정 (.record는 options 없이 사용)
                                try session.setCategory(.record, mode: .default, options: [])
                                try session.setActive(true)
                                print("[Recording] ✅ AVAudioSession 녹음 모드 설정 완료")
                            } catch {
                                print("[Recording] ⚠️ AVAudioSession 설정 실패: \(error)")
                            }
                            
                            _ = try? await recorder.startRecording()
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
                            for await _ in await clock.timer(interval: .seconds(1)) { await send(.tick) }
                        }.cancellable(id: CancelID.timer, cancelInFlight: true)
                    )
                    
                case .paused:
                    state.status = .recording
                    
                    let resumeTranscription = speechService.resumeTranscription
                    
                    return .merge(
                        .run { _ in await recorder.resumeRecording() },
                        .run { _ in resumeTranscription() },
                        .run { send in
                            for await _ in await clock.timer(interval: .seconds(1)) { await send(.tick) }
                        }.cancellable(id: CancelID.timer, cancelInFlight: true)
                    )
                    
                case .recording, .finishing:
                    return .none
                }
                
            case .pauseTapped:
                guard state.status == .recording else { return .none }
                recorder.pauseRecording()
                state.status = .paused
                
                let pauseTranscription = speechService.pauseTranscription
                
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in pauseTranscription() }
                )
                
            case .stopTapped:
                guard state.status == .recording || state.status == .paused else { return .none }
                
                state.lastRecordedLength = state.elapsedSeconds
                state.elapsedSeconds = 0
                state.status = .finishing
                
                let stopLiveTranscription = speechService.stopLiveTranscription
                
                return .merge(
                    .cancel(id: CancelID.timer),
                    .run { _ in stopLiveTranscription() },
                    // ✅ 녹음 완전히 종료되도록 대기 후 URL 가져오기
                    .run { [recorder] send in
                        // 녹음 중지
                        let url = await recorder.stopRecording()
                        
                        // ✅ 파일이 완전히 쓰여질 때까지 대기
                        try? await Task.sleep(for: .milliseconds(500))
                        
                        // ✅ URL이 유효한 경우에만 저장
                        if let url = url {
                            await send(.recordingFileSaved(url))
                        } else {
                            print("❌ 녹음 파일 URL을 가져올 수 없음")
                            await send(.recordingSaveFailed("녹음 파일을 찾을 수 없습니다"))
                        }
                    }
                )
                
            case .tick:
                if state.status == .recording { state.elapsedSeconds += 1 }
                return .none
                
            case .liveTranscriptUpdated(let transcript):
                guard !transcript.isEmpty else { return .none }
                state.liveTranscript = transcript
                return .none
                
            case .liveTranscriptFinished:
                state.finalTranscript = state.liveTranscript.isEmpty ? nil : state.liveTranscript
                print("🎤 STT 완료, 최종 transcript: \(state.finalTranscript ?? "없음")")
                return .none
                
            case .recordingFileSaved(let url):
                // ✅ 녹음 파일이 저장되면 fileURL에 저장
                state.fileURL = url
                print("🎤 녹음 파일 URL 저장됨: \(url.path)")
                return .none
                
            case .saveRecording(let tempUrl, let length, let ownerId, let context):
                let transcript = state.finalTranscript
                
                return .run { [projectLocalDataClient, fileCloudClient, firebaseClient] send in
                    do {
                        // ✅ 1. 파일 존재 및 유효성 확인
                        guard FileManager.default.fileExists(atPath: tempUrl.path) else {
                            print("❌ 임시 파일이 존재하지 않음: \(tempUrl.path)")
                            await send(.recordingSaveFailed("녹음 파일을 찾을 수 없습니다"))
                            return
                        }
                        
                        // ✅ 2. 파일이 유효한 오디오인지 확인
                        let asset = AVURLAsset(url: tempUrl)
                        let duration: CMTime
                        do {
                            duration = try await asset.load(.duration)
                            let seconds = CMTimeGetSeconds(duration)
                            print("✅ 오디오 파일 유효성 확인 완료: \(seconds)초")
                            
                            if seconds <= 0.1 || seconds.isNaN || seconds.isInfinite {
                                print("❌ 오디오 파일 길이가 유효하지 않음: \(seconds)")
                                await send(.recordingSaveFailed("녹음 파일이 손상되었습니다"))
                                return
                            }
                        } catch {
                            print("❌ 오디오 파일 유효성 검사 실패: \(error)")
                            await send(.recordingSaveFailed("녹음 파일이 손상되었습니다"))
                            return
                        }
                        
                        // ✅ 3. 안전하게 Documents로 복사
                        guard let storedPath = await copyFileToDocumentsSafely(from: tempUrl) else {
                            await send(.recordingSaveFailed("파일 저장 실패"))
                            return
                        }
                        
                        // ✅ 4. 복사된 파일도 다시 검증
                        let copiedURL = URL(fileURLWithPath: storedPath)
                        let copiedAsset = AVURLAsset(url: copiedURL)
                        do {
                            let copiedDuration = try await copiedAsset.load(.duration)
                            let seconds = CMTimeGetSeconds(copiedDuration)
                            print("✅ 복사된 파일 검증 완료: \(seconds)초")
                        } catch {
                            print("❌ 복사된 파일이 손상됨: \(error)")
                            try? FileManager.default.removeItem(atPath: storedPath)
                            await send(.recordingSaveFailed("파일 복사 중 오류 발생"))
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
                                transcript,
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
                state.liveTranscript = ""
                state.finalTranscript = nil
                state.status = .ready  // ✅ 상태 초기화
                return .send(.delegate(.projectSaved(projectId)))
                
            case .syncCompleted(let projectId):
                return .send(.delegate(.syncCompleted(projectId)))
                
            case .recordingSaveFailed(let error):
                print("❌ 녹음 저장 실패: \(error)")
                state.status = .ready  // ✅ 실패해도 상태 초기화
                state.fileURL = nil
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
    
    // ✅ 안전한 파일 복사 함수
    private func copyFileToDocumentsSafely(from url: URL) -> String? {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Documents 디렉토리를 찾을 수 없음")
            return nil
        }
        
        // 고유한 파일명 생성
        let uniqueFileName = "\(UUID().uuidString).m4a"
        let destinationURL = documentsDir.appendingPathComponent(uniqueFileName)
        
        // 기존 파일 삭제
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        
        do {
            // ✅ 파일 크기 확인
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? UInt64 {
                print("📦 원본 파일 크기: \(fileSize) bytes")
                
                if fileSize == 0 {
                    print("❌ 파일 크기가 0입니다")
                    return nil
                }
            }
            
            // ✅ 파일 복사 (move가 아닌 copy)
            try fileManager.copyItem(at: url, to: destinationURL)
            print("✅ 파일 복사 완료: \(destinationURL.path)")
            
            // ✅ 복사된 파일 크기 확인
            let copiedAttributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
            if let copiedSize = copiedAttributes[.size] as? UInt64 {
                print("📦 복사된 파일 크기: \(copiedSize) bytes")
                
                if copiedSize == 0 {
                    print("❌ 복사된 파일 크기가 0입니다")
                    try? fileManager.removeItem(at: destinationURL)
                    return nil
                }
            }
            
            // ✅ 원본 임시 파일 삭제
            try? fileManager.removeItem(at: url)
            
            return destinationURL.path
        } catch {
            print("❌ 파일 복사 실패: \(error)")
            return nil
        }
    }
}
