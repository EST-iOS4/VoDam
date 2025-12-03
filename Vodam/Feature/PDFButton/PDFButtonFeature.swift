//
//  PDFButtonFeature.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import ComposableArchitecture
import SwiftUI
import SwiftData

@Reducer
struct PDFButtonFeature {
    
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient
    @Dependency(\.fileCloudClient) var fileCloudClient
    
    @ObservableState
    struct State: Equatable {
        var title: String = "PDF 가져오기"
        var selectedPDFURL: URL? = nil
        var isImporterPresented: Bool = false
        var isProcessing: Bool = false
        var savedProjectId: String?
        
        @Presents var alert: AlertState<Action.Alert>?
    }
    
    enum PDFImportError: Error, Equatable {
        case failed
    }
    
    enum Action: Equatable {
        case tapped
        case importerPresented(Bool)
        case pdfImported(Result<URL, PDFImportError>)
        case processingStarted
        case processingFinished
        
        case savePDF(URL, ModelContext, String?)
        case pdfSaved(String)
        case pdfSaveFailed(String)
        case syncCompleted(String)
        
        case delegate(Delegate)
        
        case loginRequiredTapped
        case alert(PresentationAction<Alert>)
        
        case clearAlert
        
        enum Delegate: Equatable {
            case projectSaved(String)
            case syncCompleted(String)
        }
        
        enum Alert: Equatable {
            case loginRequired
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
            case .tapped:
                state.isImporterPresented = true
                return .none
                
            case let .importerPresented(isPresented):
                state.isImporterPresented = isPresented
                return .none
                
            case .processingStarted:
                state.isProcessing = true
                return .none
                
            case .processingFinished:
                state.isProcessing = false
                state.selectedPDFURL = nil
                return .none
                
            case let .pdfImported(result):
                switch result {
                case .success(let url):
                    print("선택된 PDF 파일:", url)
                    state.selectedPDFURL = url
                case .failure:
                    print("PDF 파일 가져오기 실패")
                }
                return .none
                
            case .savePDF(let url, let context, let ownerId):
                state.isProcessing = true
                return .run { [projectLocalDataClient, firebaseClient, fileCloudClient] send in
                    do {
                        guard let storedPath = await copyPDFToDocuments(from: url) else {
                            await send(.pdfSaveFailed("PDF 저장 실패"))
                            return
                        }
                        
                        let fileName = url.deletingPathExtension().lastPathComponent
                        
                        let storedURL = URL(fileURLWithPath: storedPath)
                        let extractedText = await PDFTextExtractor.extractText(from: storedURL, maxLength: 50000)
                        
                        if let text = extractedText {
                            print("PDF 텍스트 추출 완료: \(text.count)자")
                        } else {
                            print("PDF 텍스트 추출 실패 또는 빈 PDF")
                        }
                        
                        let payload = try await MainActor.run {
                            try projectLocalDataClient.save(
                                context,
                                fileName,
                                .pdf,
                                storedPath,
                                nil,
                                extractedText,
                                ownerId
                            )
                        }
                        print("PDF 로컬 저장 완료: \(payload.id)")
                        
                        
                        await send(.pdfSaved(payload.id))
                        
                        // 4. 로그인 유저라면 클라우드 동기화
                        if let ownerId {
                            let localURL = URL(fileURLWithPath: storedPath)
                            
                            //통합 클라이언트로 업로드 (파일 확장자 자동 감지)
                            let remotePath = try await fileCloudClient.uploadFile(
                                ownerId,
                                payload.id,
                                localURL
                            )
                            print("PDF Storage 업로드 완료: \(remotePath)")
                            
                            // Firebase DB 업로드
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
                            print("Firebase DB 업로드 완료")
                            
                            // 로컬 상태 업데이트
                            try await MainActor.run {
                                try projectLocalDataClient.updateSyncStatus(
                                    context,
                                    [payload.id],
                                    .synced,
                                    ownerId,
                                    remotePath
                                )
                            }
                            print("동기화 상태 업데이트 완료")
                            
                            //동기화 완료 알림 (리프레시 트리거)
                            await send(.syncCompleted(payload.id))
                        }
                        
                    } catch {
                        print("PDF 저장 실패: \(error)")
                        await send(.pdfSaveFailed(error.localizedDescription))
                    }
                }
                
            case .pdfSaved(let projectId):
                state.savedProjectId = projectId
                state.selectedPDFURL = nil
                state.isProcessing = false
                return .run { send in
                    try await Task.sleep(for: .milliseconds(100))
                    await send(.delegate(.projectSaved(projectId)))
                }
                
            case .syncCompleted(let projectId):
                // 동기화 완료 시 delegate로 전달
                return .send(.delegate(.syncCompleted(projectId)))
                
            case .pdfSaveFailed(let error):
                print("PDF 저장 실패: \(error)")
                state.isProcessing = false
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
                
            case .clearAlert:
                state.alert = nil
                return .none
                
            case .alert:
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
    
    private func copyPDFToDocuments(from url: URL) -> String? {
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
            print("PDF 복사 실패: \(error)")
            return nil
        }
    }
}
