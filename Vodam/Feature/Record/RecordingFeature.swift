//
//  RecordingFeature.swift
//

import ComposableArchitecture
import Foundation
import SwiftData
import AVFoundation

enum RecordingCancelID {
    static let timer = "RecordingFeature.timer"
    static let liveSTT = "RecordingFeature.liveSTT"
    static let recording = "RecordingFeature.recording"
}

@Reducer
struct RecordingFeature {
    
    @Dependency(\.audioRecorder) var recorder
    @Dependency(\.continuousClock) var clock
    @Dependency(\.speechService) var speechService
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient
    @Dependency(\.fileCloudClient) var fileCloudClient
    
    private static let ownerID = "RecordingFeature"
    
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
        var lastRecordedLength: Int = 0
        var savedProjectId: String? = nil
        
        var liveTranscript: String = ""
        
        var isProcessing: Bool = false
        var fileURL: URL? = nil
    }
    
    enum Action: Equatable {
        case startTapped
        case pauseTapped
        case stopTapped
        case tick
        
        case liveTranscriptUpdated(String)
        case recordingFileSaved(URL)
        
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
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
                // MARK: - Start
            case .startTapped:
                switch state.status {
                case .ready:
                    guard !state.isProcessing else { return .none }
                    state.isProcessing = true
                    
                    state.elapsedSeconds = 0
                    state.liveTranscript = ""
                    state.fileURL = nil
                    state.status = .recording
                    
                    return .merge(
                        .run { [recorder] _ in
                            _ = try? await recorder.startRecording()
                        },
                        
                        .run { [speechService] send in
                            guard let stream = await speechService.startLiveTranscription(Self.ownerID) else {
                                return
                            }
                            for await transcript in stream {
                                await send(.liveTranscriptUpdated(transcript))
                            }
                        }
                        .cancellable(id: RecordingCancelID.liveSTT, cancelInFlight: true),
                        
                        .run { send in
                            for await _ in await clock.timer(interval: .seconds(1)) {
                                await send(.tick)
                            }
                        }
                        .cancellable(id: RecordingCancelID.timer, cancelInFlight: true)
                    )
                    
                case .paused:
                    state.status = .recording
                    return .merge(
                        .run { [recorder] _ in await recorder.resumeRecording() },
                        .run { [speechService] _ in await speechService.resumeTranscription(Self.ownerID) },
                        .run { send in
                            for await _ in await clock.timer(interval: .seconds(1)) {
                                await send(.tick)
                            }
                        }
                        .cancellable(id: RecordingCancelID.timer, cancelInFlight: true)
                    )
                    
                default:
                    return .none
                }
                
                // MARK: - Pause
            case .pauseTapped:
                guard state.status == .recording else { return .none }
                
                recorder.pauseRecording()
                state.status = .paused
                
                return .merge(
                    .cancel(id: RecordingCancelID.timer),
                    .run { [speechService] _ in await speechService.pauseTranscription(Self.ownerID) }
                )
                
                // MARK: - Stop
            case .stopTapped:
                guard state.status == .recording || state.status == .paused else { return .none }
                guard state.isProcessing else { return .none }
                
                state.lastRecordedLength = state.elapsedSeconds
                state.elapsedSeconds = 0
                state.status = .finishing
                
                return .merge(
                    .cancel(id: RecordingCancelID.timer),
                    .cancel(id: RecordingCancelID.liveSTT),
                    
                    .run { [speechService] _ in
                        await speechService.stopLiveTranscription(Self.ownerID)
                    },
                    
                    .run { [recorder] send in
                        let url = await recorder.stopRecording()
                        if let url {
                            await send(.recordingFileSaved(url))
                        } else {
                            await send(.recordingSaveFailed("녹음 파일을 찾을 수 없습니다"))
                        }
                    }
                )
                
                // MARK: - Tick
            case .tick:
                if state.status == .recording {
                    state.elapsedSeconds += 1
                }
                return .none
                
            case .liveTranscriptUpdated(let txt):
                if !txt.isEmpty { state.liveTranscript = txt }
                return .none
                
            case .recordingFileSaved(let url):
                state.fileURL = url
                return .none
                
                // MARK: - Save
            case .saveRecording(let tempUrl, let length, let ownerId, let context):
                let transcript: String? = state.liveTranscript.isEmpty ? nil : state.liveTranscript
                
                return .run { [projectLocalDataClient, fileCloudClient, firebaseClient] send in
                    do {
                        guard FileManager.default.fileExists(atPath: tempUrl.path) else {
                            await send(.recordingSaveFailed("녹음 파일을 찾을 수 없습니다"))
                            return
                        }
                        
                        let asset = AVURLAsset(url: tempUrl)
                        do {
                            let duration = try await asset.load(.duration)
                            let seconds = CMTimeGetSeconds(duration)
                            if seconds <= 0.1 || seconds.isNaN || seconds.isInfinite {
                                await send(.recordingSaveFailed("녹음 파일이 손상되었습니다"))
                                return
                            }
                        } catch {
                            await send(.recordingSaveFailed("녹음 파일이 손상되었습니다"))
                            return
                        }
                        
                        guard let storedPath = await copyFileToDocumentsSafely(from: tempUrl) else {
                            await send(.recordingSaveFailed("파일 저장 실패"))
                            return
                        }
                        
                        let copiedURL = URL(fileURLWithPath: storedPath)
                        let copiedAsset = AVURLAsset(url: copiedURL)
                        do {
                            let copiedDuration = try await copiedAsset.load(.duration)
                            let seconds = CMTimeGetSeconds(copiedDuration)
                            print("✅ 파일 검증 완료: \(seconds)초")
                        } catch {
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
                        print("✅ 로컬 저장 완료: \(payload.id)")
                        
                        await send(.recordingSaved(payload.id))
                        
                        if let ownerId {
                            do {
                                let localURL = URL(fileURLWithPath: storedPath)
                                guard FileManager.default.fileExists(atPath: localURL.path) else {
                                    throw NSError(domain: "RecordingFeature", code: -1)
                                }
                                
                                let remotePath = try await fileCloudClient.uploadFile(ownerId, payload.id, localURL)
                                
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
                                
                                try await MainActor.run {
                                    try projectLocalDataClient.updateSyncStatus(context, [payload.id], .synced, ownerId, remotePath)
                                }
                                
                                await send(.syncCompleted(payload.id))
                            } catch {
                                print("❌ 클라우드 동기화 실패: \(error.localizedDescription)")
                            }
                        }
                        
                    } catch {
                        await send(.recordingSaveFailed(error.localizedDescription))
                    }
                }
                
            case .recordingSaved(let id):
                state.savedProjectId = id
                state.fileURL = nil
                state.liveTranscript = ""
                state.status = .ready
                state.isProcessing = false
                return .send(.delegate(.projectSaved(id)))
                
            case .syncCompleted(let id):
                return .send(.delegate(.syncCompleted(id)))
                
            case .recordingSaveFailed:
                state.status = .ready
                state.fileURL = nil
                state.isProcessing = false
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
    
    private func copyFileToDocumentsSafely(from url: URL) async -> String? {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let uniqueFileName = "\(UUID().uuidString).m4a"
        let destinationURL = documentsDir.appendingPathComponent(uniqueFileName)
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? UInt64, fileSize == 0 {
                return nil
            }
            
            try fileManager.copyItem(at: url, to: destinationURL)
            
            let copiedAttributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
            if let copiedSize = copiedAttributes[.size] as? UInt64, copiedSize == 0 {
                try? fileManager.removeItem(at: destinationURL)
                return nil
            }
            
            try? fileManager.removeItem(at: url)
            
            return destinationURL.path
        } catch {
            return nil
        }
    }
}
