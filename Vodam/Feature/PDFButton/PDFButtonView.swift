//
//  PDFButtonView.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import SwiftData

struct PDFButtonView: View {
    let store: StoreOf<PDFButtonFeature>

    @Environment(\.modelContext) var context
    let ownerId: String?

    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient
    @Dependency(\.audioCloudClient) var audioCloudClient

    init(store: StoreOf<PDFButtonFeature>, ownerId: String? = nil) {
        self.store = store
        self.ownerId = ownerId
    }

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                // 카드 배경
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)

                // 내부 UI
                HStack(spacing: 20) {

                    // 아이콘 (FileButtonView와 동일한 구조로 수정)
                    Image(systemName: "doc.richtext.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.red)
                        )
                        .shadow(
                            color: .black.opacity(0.15),
                            radius: 3,
                            x: 0,
                            y: 2
                        )

                    // 텍스트
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewStore.title)
                            .font(.headline)

                        if viewStore.isProcessing {
                            Text("텍스트 추출 중...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                    }

                    Spacer()

                    if viewStore.isProcessing {
                        ProgressView()
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
                    send: PDFButtonFeature.Action.importerPresented
                ),
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewStore.send(.pdfImported(.success(url)))
                    } else {
                        viewStore.send(.pdfImported(.failure(.failed)))
                    }

                case .failure:
                    viewStore.send(.pdfImported(.failure(.failed)))
                }
            }
            .onChange(of: viewStore.selectedPDFURL) { _, newValue in
                guard let url = newValue else { return }
                viewStore.send(.processingStarted)
                saveProject(url: url)
            }
        }
    }

    // MARK: - PDF 저장
    private func saveProject(url: URL) {
        Task {
            do {
                let projectName = url.deletingPathExtension().lastPathComponent

                guard let copiedPath = copyFileToDocuments(url: url) else {
                    print("❌ PDF 파일 복사 실패")
                    store.send(.processingFinished)
                    return
                }

                let extractedText = extractTextFromPDF(at: url)
                let transcript = extractedText.isEmpty ? nil : extractedText

                print("PDF 텍스트 추출 완료: \(extractedText.prefix(100))...")

                let payload = try projectLocalDataClient.save(
                    context,
                    projectName,
                    .pdf,
                    copiedPath,
                    nil,  // fileLength
                    transcript,
                    ownerId
                )

                print("PDF 프로젝트 저장 성공 → \(payload.name)")

                if let ownerId {
                    do {
                        // Storage에 PDF 파일 업로드
                        let localURL = URL(fileURLWithPath: copiedPath)
                        let remotePath = try await audioCloudClient.uploadAudio(
                            ownerId,
                            payload.id,
                            localURL
                        )

                        print("Storage 업로드 완료: \(remotePath)")

                        // Firestore에 메타데이터 저장
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

                        try await firebaseClient.uploadProjects(
                            ownerId,
                            [syncedPayload]
                        )

                        // SwiftData 업데이트
                        try projectLocalDataClient.updateSyncStatus(
                            context,
                            [payload.id],
                            .synced,
                            ownerId,
                            remotePath
                        )

                        print("Firebase + Storage 업로드 성공")
                    } catch {
                        print("Firebase/Storage 업로드 실패: \(error)")
                    }
                } else {
                    print("비회원 모드: Firebase/Storage 업로드 생략")
                }

                store.send(.processingFinished)

            } catch {
                print("PDF 프로젝트 저장 실패: \(error)")
                store.send(.processingFinished)
            }
        }
    }

    // MARK: - PDF 텍스트 추출
    private func extractTextFromPDF(at url: URL) -> String {
        guard url.startAccessingSecurityScopedResource() else {
            print("⚠️ Security-scoped resource 접근 실패")
            return ""
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let pdfDocument = PDFDocument(url: url) else {
            print("PDF 문서 로드 실패")
            return ""
        }

        var fullText = ""

        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            guard let pageText = page.string else { continue }
            fullText += pageText + "\n"
        }

        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 파일 복사
    private func copyFileToDocuments(url: URL) -> String? {
        let fileManager = FileManager.default
        guard
            let documentsDir = fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first
        else { return nil }

        let destinationURL = documentsDir.appendingPathComponent(
            url.lastPathComponent
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            try fileManager.copyItem(at: url, to: destinationURL)
            print("PDF 파일 복사 성공: \(destinationURL.path)")
            return destinationURL.path
        } catch {
            print("PDF 파일 복사 실패: \(error)")
            return nil
        }
    }
}
