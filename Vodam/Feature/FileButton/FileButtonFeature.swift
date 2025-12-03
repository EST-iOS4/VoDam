//
//  FileButtonFeature.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import ComposableArchitecture
import Speech
import SwiftUI
import SwiftData
import AVFoundation

@Reducer
struct FileButtonFeature {
    
    @Dependency(\.audioFileSTTClient) var sttClient
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient
    @Dependency(\.fileCloudClient) var fileCloudClient
    
    @ObservableState
    struct State: Equatable {
        var title: String = "파일 가져오기"
        var selectedFileURL: URL?
        var isImporterPresented: Bool = false
        var isTranscribing: Bool = false
        var transcript: String = ""
        var errorMessage: String?
        var savedProjectId: String?
        var progress: Double = 0
    }
    
    enum Action: Equatable {
        case tapped
        case importerPresented(Bool)
        case fileImported(Result<URL, FileImportError>)
        
        case startSTT(URL)
        case sttResponse(Result<String, STTError>)
        
        case saveFile(URL, String?, ModelContext, String?)
        case fileSaved(String)
        case fileSaveFailed(String)
        case syncCompleted(String)
        
        case delegate(Delegate)
        case sttProgressUpdated(Double)
        
        enum Delegate: Equatable {
            case projectSaved(String)
            case syncCompleted(String)
        }
    }
    
    enum FileImportError: Error, Equatable {
        case failed
    }
    
    enum STTError: Error, Equatable {
        case failed(String)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
            case .tapped:
                state.isImporterPresented = true
                return .none
                
            case .importerPresented(let isPresented):
                state.isImporterPresented = isPresented
                return .none
                
            case .fileImported(let result):
                switch result {
                case .success(let url):
                    print("📁 선택된 파일:", url)
                    state.selectedFileURL = url
                    return .send(.startSTT(url))
                    
                case .failure:
                    state.errorMessage = "파일 선택 실패"
                    return .none
                }
                
            case .startSTT(let url):
                state.isTranscribing = true
                state.progress = 0
                print("🎤 STT 시작: \(url.lastPathComponent)")
                return .run { [url, sttClient] send in
                    let result = await sttClient.transcribe(url) { progress in
                        await send(.sttProgressUpdated(progress))
                    }
                    await send(.sttResponse(result))
                }
            case .sttProgressUpdated(let progress):
                state.progress = progress
                return .none
                
                
            case .sttResponse(let result):
                state.isTranscribing = false
                state.progress = 0
                
                switch result {
                case .success(let text):
                    print("📄 STT 결과:")
                    print(text)
                    state.transcript = text
                    
                case .failure(let error):
                    print("❌ STT 실패:", error)
                    state.errorMessage = "STT 실패: \(error)"
                }
                return .none
                
            case .saveFile(let url, let transcript, let context, let ownerId):
                return .run { [projectLocalDataClient, fileCloudClient, firebaseClient] send in
                    do {
                        guard let storedPath = await copyFileToDocuments(from: url) else {
                            await send(.fileSaveFailed("파일 저장 실패"))
                            return
                        }
                        
                        let fileName = url.deletingPathExtension().lastPathComponent
                        
                        var fileLength: Int? = nil
                        if let duration = await getAudioDuration(url: URL(fileURLWithPath: storedPath)) {
                            fileLength = Int(duration)
                        }
                        
                        let payload = try await MainActor.run {
                            try projectLocalDataClient.save(
                                context,
                                fileName,
                                .file,
                                storedPath,
                                fileLength,
                                transcript,
                                ownerId
                            )
                        }
                        print("📁 파일 로컬 저장 완료: \(payload.id)")
                        
                        await send(.fileSaved(payload.id))
                        
                        if let ownerId {
                            let localURL = URL(fileURLWithPath: storedPath)
                            
                            let remotePath = try await fileCloudClient.uploadFile(
                                ownerId,
                                payload.id,
                                localURL
                            )
                            
                            let syncedPayload = await ProjectPayload(
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
                                try projectLocalDataClient.updateSyncStatus(
                                    context,
                                    [payload.id],
                                    .synced,
                                    ownerId,
                                    remotePath
                                )
                            }
                            print("☁️ 클라우드 동기화 완료")
                            await send(.syncCompleted(payload.id))
                        }
                        
                    } catch {
                        print("❌ 파일 저장 실패: \(error)")
                        await send(.fileSaveFailed(error.localizedDescription))
                    }
                }
                
            case .fileSaved(let projectId):
                state.savedProjectId = projectId
                state.selectedFileURL = nil
                state.transcript = ""
                return .run { send in
                    try await Task.sleep(for: .milliseconds(100))
                    await send(.delegate(.projectSaved(projectId)))
                }
                
            case .syncCompleted(let projectId):
                return .run { send in
                    try await Task.sleep(for: .milliseconds(100))
                    await send(.delegate(.syncCompleted(projectId)))
                }
                
            case .fileSaveFailed(let error):
                print("파일 저장 실패: \(error)")
                state.errorMessage = error
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
            guard url.startAccessingSecurityScopedResource() else {
                print("Security scoped resource 접근 실패")
                return nil
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            try fileManager.copyItem(at: url, to: destinationURL)
            return destinationURL.path
        } catch {
            print("파일 복사 실패: \(error)")
            return nil
        }
    }
    
    private func getAudioDuration(url: URL) -> Double? {
        let asset = AVURLAsset(url: url)
        let duration = asset.duration
        return CMTimeGetSeconds(duration)
    }
}
