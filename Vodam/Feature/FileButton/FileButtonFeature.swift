//
//  FileButtonFeature.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import AVFoundation
import ComposableArchitecture
import Speech
import SwiftUI
import SwiftData

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
        
        @Presents var alert: AlertState<Action.Alert>?
        
        // STT 상태
        var isTranscribing: Bool = false
        var transcript: String = ""
        var errorMessage: String?
        
        // 저장된 프로젝트 ID
        var savedProjectId: String?
    }
    
    enum Action: Equatable {
        case tapped
        case importerPresented(Bool)
        case fileImported(Result<URL, FileImportError>)
        
        // STT
        case startSTT(URL)
        case sttResponse(Result<String, STTError>)
        
        // 저장
        case saveFile(URL, String?, ModelContext, String?)  // url, transcript, context, ownerId
        case fileSaved(String)
        case fileSaveFailed(String)
        case syncCompleted(String)
        
        case loginRequiredTapped
        case alert(PresentationAction<Alert>)
        
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case projectSaved(String)
            case syncCompleted(String)
        }
        
        enum Alert: Equatable {
            case loginRequired
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
                
                // 파일 선택 클릭
            case .tapped:
                state.isImporterPresented = true
                return .none
                
            case .importerPresented(let isPresented):
                state.isImporterPresented = isPresented
                return .none
                
                // 파일 선택 후
            case .fileImported(let result):
                switch result {
                case .success(let url):
                    print("📁 선택된 파일:", url)
                    state.selectedFileURL = url
                    // 선택됨 → STT 실행
                    return .send(.startSTT(url))
                    
                case .failure:
                    state.errorMessage = "파일 선택 실패"
                    return .none
                }
                
                // STT 시작
            case .startSTT(let url):
                state.isTranscribing = true
                print("🎤 STT 시작: \(url.lastPathComponent)")
                return .run { [url, sttClient] send in
                    let result = await sttClient.transcribe(url)
                    await send(.sttResponse(result))
                }
                
                // STT 결과 전달
            case .sttResponse(let result):
                state.isTranscribing = false
                print("🎤 STT 종료")
                
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
                
                // 저장 로직
            case .saveFile(let url, let transcript, let context, let ownerId):
                return .run { [projectLocalDataClient, fileCloudClient, firebaseClient] send in
                    do {
                        // 1. 파일을 Documents로 복사
                        guard let storedPath = await copyFileToDocuments(from: url) else {
                            await send(.fileSaveFailed("파일 저장 실패"))
                            return
                        }
                        
                        // 2. 파일 이름 생성
                        let fileName = url.deletingPathExtension().lastPathComponent
                        
                        // 3. 파일 길이 계산 (오디오 파일인 경우)
                        var fileLength: Int? = nil
                        if let duration = await getAudioDuration(url: URL(fileURLWithPath: storedPath)) {
                            fileLength = Int(duration)
                        }
                        
                        // 4. SwiftData에 저장 - MainActor에서 실행
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
                        
                        // 5. 로그인 유저라면 클라우드 업로드
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
                            
                            // MainActor에서 실행
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
                
            case .loginRequiredTapped:
                state.alert = AlertState {
                    TextState("로그인이 필요합니다.")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("확인")
                    }
                } message: {
                    TextState("로그인 후 이용할 수 있습니다.")
                }
                return .none
                
            case .alert:
                return .none
                
            case .delegate:
                return .none
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
            // Security-scoped resource 접근
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
