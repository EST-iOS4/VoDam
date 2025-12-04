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
    @Dependency(\.pdfOCRClient) var pdfOCRClient

    @ObservableState
    struct State: Equatable {
        var title: String = "PDF 가져오기"
        var selectedPDFURL: URL? = nil
        var isImporterPresented: Bool = false
        var isProcessing: Bool = false
        var savedProjectId: String?
        
        @Presents var alert: AlertState<Action.Alert>?

        var progress: Double = 0
        var errorMessage: String?
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
        
        case startOCR(URL, String?)
        case ocrProgressUpdated(Double)
        case ocrCompleted(URL, String?, String?)
        case ocrFailed(String)
        
        case savePDF(URL, String?, String?)
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
                state.progress = 0
                return .none
                
            case let .pdfImported(result):
                switch result {
                case .success(let url):
                    print("📄 선택된 PDF 파일:", url)
                    state.selectedPDFURL = url
                    state.errorMessage = nil
                case .failure:
                    print("PDF 파일 가져오기 실패")
                    state.errorMessage = "PDF 파일 가져오기 실패"
                }
                return .none
                
            case .startOCR(let url, let ownerId):
                state.isProcessing = true
                state.progress = 0
                print("📄 PDF OCR 시작: \(url.lastPathComponent)")
                
                return .run { [pdfOCRClient] send in
                    let result = await pdfOCRClient.extractText(url) { progress in
                        await send(.ocrProgressUpdated(progress))
                    }
                    
                    switch result {
                    case .success(let text):
                        await send(.ocrCompleted(url, text, ownerId))
                    case .failure(let error):
                        await send(.ocrFailed(error.localizedDescription))
                    }
                }
                
            case .ocrProgressUpdated(let progress):
                state.progress = progress
                return .none
                
            case .ocrCompleted(let url, let text, let ownerId):
                print("📄 OCR 완료: \(text?.count ?? 0)자")
                return .send(.savePDF(url, text, ownerId))
                
            case .ocrFailed(let error):
                print("❌ OCR 실패: \(error)")
                state.isProcessing = false
                state.progress = 0
                state.errorMessage = "OCR 실패: \(error)"
                return .none
                
            case .savePDF(let url, let transcript, let ownerId):
                return .run { [projectLocalDataClient, firebaseClient, fileCloudClient] send in
                    do {
                        guard let storedPath = await copyPDFToDocuments(from: url) else {
                            await send(.pdfSaveFailed("PDF 저장 실패"))
                            return
                        }
                        
                        let fileName = url.deletingPathExtension().lastPathComponent
                        
                        let payload = try await projectLocalDataClient.save(
                            fileName,
                            .pdf,
                            storedPath,
                            nil,
                            transcript,
                            ownerId
                        )
                        print("📄 PDF 로컬 저장 완료: \(payload.id)")
                        
                        let transcriptPath = await saveTranscriptToFile(transcript, projectId: payload.id)

                        await send(.pdfSaved(payload.id))
                        
                        if let ownerId {
                            let localURL = URL(fileURLWithPath: storedPath)
                            
                            // PDF 파일 업로드
                            let remotePath = try await fileCloudClient.uploadFile(
                                ownerId,
                                payload.id,
                                localURL
                            )
                            print("☁️ PDF Storage 업로드 완료: \(remotePath)")
                            
                            var remoteTranscriptPath: String? = nil
                            let transcriptSize = transcript?.utf8.count ?? 0
                            
                            let maxFirestoreSize = 900_000
                            
                            let finalTranscript: String?
                            if transcriptSize > maxFirestoreSize, let transcriptPath {
                                let transcriptURL = URL(fileURLWithPath: transcriptPath)
                                remoteTranscriptPath = try await fileCloudClient.uploadFile(
                                    ownerId,
                                    "\(payload.id)_transcript",
                                    transcriptURL
                                )
                                
                                finalTranscript = String(transcript?.prefix(1000) ?? "") + "... (전체 텍스트는 Storage에 저장됨)"
                                print("☁️ Transcript Storage 업로드 완료: \(remoteTranscriptPath ?? "")")
                            } else {
                                finalTranscript = transcript
                            }
                            
                            let syncedPayload = ProjectPayload(
                                id: payload.id,
                                name: payload.name,
                                creationDate: payload.creationDate,
                                category: payload.category,
                                isFavorite: payload.isFavorite,
                                filePath: payload.filePath,
                                fileLength: payload.fileLength,
                                transcript: finalTranscript,
                                ownerId: ownerId,
                                syncStatus: .synced,
                                remoteAudioPath: remotePath
                            )
                            
                            try await firebaseClient.uploadProjects(ownerId, [syncedPayload])
                            print("☁️ Firebase DB 업로드 완료")
                            
                            try await projectLocalDataClient.updateSyncStatus(
                                [payload.id],
                                .synced,
                                ownerId,
                                remotePath
                            )
                            print("☁️ 동기화 상태 업데이트 완료")
                            
                            await send(.syncCompleted(payload.id))
                        }
                        
                    } catch {
                        print("❌ PDF 저장 실패: \(error)")
                        await send(.pdfSaveFailed(error.localizedDescription))
                    }
                }
                
            case .pdfSaved(let projectId):
                state.savedProjectId = projectId
                state.selectedPDFURL = nil
                state.isProcessing = false
                state.progress = 0
                return .run { send in
                    try await Task.sleep(for: .milliseconds(100))
                    await send(.delegate(.projectSaved(projectId)))
                }
                
            case .syncCompleted(let projectId):
                return .send(.delegate(.syncCompleted(projectId)))
                
            case .pdfSaveFailed(let error):
                print("PDF 저장 실패: \(error)")
                state.isProcessing = false
                state.progress = 0
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
                
            case .clearAlert:
                state.alert = nil
                return .none
                
            case .alert:
                return .none
                
            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
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
    
    /// transcript를 로컬 파일로 저장
    private func saveTranscriptToFile(_ transcript: String?, projectId: String) -> String? {
        guard let transcript, !transcript.isEmpty else { return nil }
        
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let transcriptURL = documentsDir.appendingPathComponent("\(projectId)_transcript.txt")
        
        do {
            try transcript.write(to: transcriptURL, atomically: true, encoding: .utf8)
            return transcriptURL.path
        } catch {
            print("Transcript 저장 실패: \(error)")
            return nil
        }
    }
}
