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
    @Dependency(\.pdfOCRClient) var pdfOCRClient  // 추가

    @ObservableState
    struct State: Equatable {
        var title: String = "PDF 가져오기"
        var selectedPDFURL: URL? = nil
        var isImporterPresented: Bool = false
        var isProcessing: Bool = false
        var savedProjectId: String?
        var progress: Double = 0  // 추가
        var errorMessage: String?  // 추가
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
        
        // OCR 추가
        case startOCR(URL, ModelContext, String?)
        case ocrProgressUpdated(Double)
        case ocrCompleted(URL, String?, ModelContext, String?)  // url, text, context, ownerId
        case ocrFailed(String)
        
        case savePDF(URL, String?, ModelContext, String?)  // transcript 파라미터 추가
        case pdfSaved(String)
        case pdfSaveFailed(String)
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
                
            // MARK: - OCR
            case .startOCR(let url, let context, let ownerId):
                state.isProcessing = true
                state.progress = 0
                print("📄 PDF OCR 시작: \(url.lastPathComponent)")
                
                return .run { [pdfOCRClient] send in
                    let result = await pdfOCRClient.extractText(url) { progress in
                        await send(.ocrProgressUpdated(progress))
                    }
                    
                    switch result {
                    case .success(let text):
                        await send(.ocrCompleted(url, text, context, ownerId))
                    case .failure(let error):
                        await send(.ocrFailed(error.localizedDescription))
                    }
                }
                
            case .ocrProgressUpdated(let progress):
                state.progress = progress
                return .none
                
            case .ocrCompleted(let url, let text, let context, let ownerId):
                print("📄 OCR 완료: \(text?.count ?? 0)자")
                return .send(.savePDF(url, text, context, ownerId))
                
            case .ocrFailed(let error):
                print("❌ OCR 실패: \(error)")
                state.isProcessing = false
                state.progress = 0
                state.errorMessage = "OCR 실패: \(error)"
                return .none
                
            // MARK: - 저장
            case .savePDF(let url, let transcript, let context, let ownerId):
                return .run { [projectLocalDataClient, firebaseClient, fileCloudClient] send in
                    do {
                        guard let storedPath = await copyPDFToDocuments(from: url) else {
                            await send(.pdfSaveFailed("PDF 저장 실패"))
                            return
                        }
                        
                        let fileName = url.deletingPathExtension().lastPathComponent
                        
                        let payload = try await MainActor.run {
                            try projectLocalDataClient.save(
                                context,
                                fileName,
                                .pdf,
                                storedPath,
                                nil,
                                transcript,  // OCR 결과 사용
                                ownerId
                            )
                        }
                        print("📄 PDF 로컬 저장 완료: \(payload.id)")
                        
                        await send(.pdfSaved(payload.id))
                        
                        if let ownerId {
                            let localURL = URL(fileURLWithPath: storedPath)
                            
                            let remotePath = try await fileCloudClient.uploadFile(
                                ownerId,
                                payload.id,
                                localURL
                            )
                            print("☁️ PDF Storage 업로드 완료: \(remotePath)")
                            
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
                            print("☁️ Firebase DB 업로드 완료")
                            
                            try await MainActor.run {
                                try projectLocalDataClient.updateSyncStatus(
                                    context,
                                    [payload.id],
                                    .synced,
                                    ownerId,
                                    remotePath
                                )
                            }
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
