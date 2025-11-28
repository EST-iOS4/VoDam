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

    @ObservableState
    struct State: Equatable {
        var title: String = "PDF 가져오기"
        var selectedPDFURL: URL? = nil
        var isImporterPresented: Bool = false
        var isProcessing: Bool = false
        var savedProjectId: String?
    }

    // PDF 선택 에러
    enum PDFImportError: Error, Equatable {
        case failed
    }

    enum Action: Equatable {
        case tapped
        case importerPresented(Bool)
        case pdfImported(Result<URL, PDFImportError>)
        case processingStarted
        case processingFinished
        
        // 저장
        case savePDF(URL, ModelContext, String?)  // url, context, ownerId
        case pdfSaved(String)
        case pdfSaveFailed(String)
        
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case projectSaved(String)
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
                    print("📄 선택된 PDF 파일:", url)
                    state.selectedPDFURL = url
                case .failure:
                    print("❌ PDF 파일 가져오기 실패")
                }
                return .none
                
            // 저장 로직
            case .savePDF(let url, let context, let ownerId):
                state.isProcessing = true
                return .run { [projectLocalDataClient, firebaseClient] send in
                    do {
                        // 1. 파일을 Documents로 복사
                        guard let storedPath = copyPDFToDocuments(from: url) else {
                            await send(.pdfSaveFailed("PDF 저장 실패"))
                            return
                        }
                        
                        // 2. 파일 이름
                        let fileName = url.deletingPathExtension().lastPathComponent
                        
                        // 3. SwiftData에 저장 - MainActor에서 실행
                        let payload = try await MainActor.run {
                            try projectLocalDataClient.save(
                                context,
                                fileName,
                                .pdf,
                                storedPath,
                                nil,  // PDF는 길이 없음
                                nil,  // transcript
                                ownerId
                            )
                        }
                        print("📄 PDF 로컬 저장 완료: \(payload.id)")
                        
                        await send(.pdfSaved(payload.id))
                        
                        // 4. 로그인 유저라면 클라우드 업로드
                        if let ownerId {
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
                                remoteAudioPath: nil
                            )
                            
                            try await firebaseClient.uploadProjects(ownerId, [syncedPayload])
                            
                            // MainActor에서 실행
                            try await MainActor.run {
                                try projectLocalDataClient.updateSyncStatus(
                                    context,
                                    [payload.id],
                                    .synced,
                                    ownerId,
                                    nil
                                )
                            }
                            print("☁️ PDF 클라우드 동기화 완료")
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
                return .send(.delegate(.projectSaved(projectId)))
                
            case .pdfSaveFailed(let error):
                print("PDF 저장 실패: \(error)")
                state.isProcessing = false
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
    
    // MARK: - Helper
    private func copyPDFToDocuments(from url: URL) -> String? {
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
            print("PDF 복사 실패: \(error)")
            return nil
        }
    }
}
