//
//  FileButtonView.swift
//  VoDam
//

import ComposableArchitecture
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct FileButtonView: View {
    @Environment(\.modelContext) var context
    let store: StoreOf<FileButtonFeature>
    let ownerId: String?
    
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient
    
    init(store: StoreOf<FileButtonFeature>, ownerId: String? = nil) {
        self.store = store
        self.ownerId = ownerId
    }

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            VStack(spacing: 16) {
                buttonContent(viewStore)
                
                if let error = viewStore.errorMessage {
                    Text("에러: \(error)")
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }
            }
            // STT 완료 후 저장 처리
            .onChange(of: viewStore.isTranscribing) { wasTranscribing, isTranscribing in
                // STT가 완료되었고 (false), 선택된 파일이 있고, 에러가 없을 때
                if !isTranscribing && wasTranscribing,
                   let url = viewStore.selectedFileURL,
                   viewStore.errorMessage == nil {
                    let transcript = viewStore.transcript.isEmpty ? nil : viewStore.transcript
                    saveProject(url: url, transcript: transcript)
                }
            }
        }
    }
    
    // MARK: - Button Content
    @ViewBuilder
    private func buttonContent(_ viewStore: ViewStoreOf<FileButtonFeature>) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 6,
                    x: 0,
                    y: 4
                )

            HStack(spacing: 20) {
                iconView
                
                textContent(viewStore)
                
                Spacer()
                
                if viewStore.isTranscribing {
                    ProgressView()
                        .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 80)
        .padding(.horizontal, 20)
        .onTapGesture {
            viewStore.send(.tapped)
        }
        .fileImporter(
            isPresented: viewStore.binding(
                get: \.isImporterPresented,
                send: FileButtonFeature.Action.importerPresented
            ),
            allowedContentTypes: [.wav, .mp3, .mpeg4Audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewStore.send(.fileImported(.success(url)))
                } else {
                    viewStore.send(.fileImported(.failure(.failed)))
                }
            case .failure:
                viewStore.send(.fileImported(.failure(.failed)))
            }
        }
    }
    
    @ViewBuilder
    private var iconView: some View {
        Image(systemName: "folder.fill")
            .foregroundColor(.white)
            .font(.system(size: 24))
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 24).fill(Color.blue)
            )
            .shadow(
                color: .black.opacity(0.15),
                radius: 3,
                x: 0,
                y: 2
            )
    }
    
    @ViewBuilder
    private func textContent(_ viewStore: ViewStoreOf<FileButtonFeature>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewStore.title)
                .font(.headline)
                .foregroundColor(.black)
            
            if viewStore.isTranscribing {
                Text("변환 중...")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - SwiftData 저장
    private func saveProject(url: URL, transcript: String?) {
        do {
            let projectName = url.deletingPathExtension().lastPathComponent
            
            // 파일을 앱의 Documents 디렉토리로 복사
            guard let copiedPath = copyFileToDocuments(url: url) else {
                print("❌ 파일 복사 실패")
                return
            }
            
            let payload = try projectLocalDataClient.save(
                context,
                projectName,
                .file,
                copiedPath,
                nil, // fileLength - 오디오 파일은 나중에 계산
                transcript,
                ownerId
            )
            
            print("✅ 파일 프로젝트 저장 성공 → \(payload.name)")
            
            // 로그인 사용자면 Firebase 업로드
            if let ownerId {
                Task {
                    do {
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
                            syncStatus: .synced
                        )
                        
                        try await firebaseClient.uploadProjects(ownerId, [syncedPayload])
                        try projectLocalDataClient.updateSyncStatus(
                            context, [payload.id], .synced, ownerId
                        )
                        
                        print("✅ Firebase 업로드 성공")
                    } catch {
                        print("❌ Firebase 업로드 실패: \(error)")
                    }
                }
            }
            
        } catch {
            print("❌ 파일 프로젝트 저장 실패: \(error)")
        }
    }
    
    // MARK: - 파일 복사
    private func copyFileToDocuments(url: URL) -> String? {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return nil }
        
        let destinationURL = documentsDir.appendingPathComponent(url.lastPathComponent)
        
        // 이미 존재하면 삭제
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }
        
        // Security scoped access
        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            try fileManager.copyItem(at: url, to: destinationURL)
            return destinationURL.path
        } catch {
            print("파일 복사 실패: \(error)")
            return url.path
        }
    }
}
