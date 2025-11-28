//
//  RecordingView.swift
//  VoDam
//

import ComposableArchitecture
import SwiftData
import SwiftUI

struct RecordingView: View {
    @Environment(\.modelContext) var context
    let store: StoreOf<RecordingFeature>

    let ownerId: String?
    
    let showLiveTranscript: Bool

    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient

    init(
        store: StoreOf<RecordingFeature>,
        ownerId: String?,
        showLiveTranscript: Bool = false
    ) {
        self.store = store
        self.ownerId = ownerId
        self.showLiveTranscript = showLiveTranscript
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)

            VStack(spacing: 24) {
                controls(
                    status: store.status,
                    onStart: { store.send(.startTapped) },
                    onPause: { store.send(.pauseTapped) },
                    onStop: { store.send(.stopTapped) }
                )

                Text(store.status.localizedText)
                    .font(.headline)

                Text(store.elapsedSeconds.formattedTime)
                    .font(.system(size: 32, weight: .medium))
                    .monospacedDigit()
                
                if showLiveTranscript,
                   (store.status == .recording || store.status == .finishing),
                   !store.liveTranscript.isEmpty {
                    Text(store.liveTranscript)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .padding(.horizontal)
                }
                
                if store.status == .finishing {
                    ProgressView()
                }
            }
            .padding(.vertical, 40)
        }
        .frame(height: 240)
        .padding(.horizontal, 20)
        
        .onChange(of: store.finalTranscript) { _, newTranscript in
            guard let url = store.fileURL,
                  store.status == .ready else { return }
            saveRecording(url: url, length: store.lastRecordedLength, transcript: newTranscript)
        }
        .onChange(of: store.status) { oldStatus, newStatus in
            guard oldStatus == .finishing,
                  newStatus == .ready,
                  let url = store.fileURL else { return }
            
            if store.finalTranscript == nil {
                saveRecording(url: url, length: store.lastRecordedLength, transcript: nil)
            }
        }
    }

    // MARK: - 녹음 저장
    private func saveRecording(url: URL, length: Int, transcript: String?) {
        do {
            guard let storedPath = copyRecordedFileToDocuments(url: url) else {
                print("녹음 파일 복사 실패")
                return
            }

            let projectName = generateProjectName(from: url)
            
            // ProjectLocalDataClient로 저장 (ProjectModel 사용)
            let payload = try projectLocalDataClient.save(
                context,
                projectName,
                .audio,
                storedPath,
                length,
                transcript,
                ownerId
            )

            print("✅ 녹음 저장 성공 → \(payload.name), id: \(payload.id), ownerId: \(payload.ownerId ?? "nil")")
            
            store.send(.recordingSaved(payload.id))
            
            // Firebase 업로드 (로그인 상태일 때만)
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
                        print("✅ Firebase 업로드 성공")
                    } catch {
                        print("❌ Firebase 업로드 실패: \(error)")
                    }
                }
            }
            
        } catch {
            print("❌ 녹음 저장 실패: \(error)")
            store.send(.recordingSaveFailed(error.localizedDescription))
        }
    }

    // MARK: - 파일 복사
    private func copyRecordedFileToDocuments(url: URL) -> String? {
        let fileManager = FileManager.default

        guard
            let documentsDir = fileManager.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first
        else {
            print("Documents 디렉토리 조회 실패")
            return nil
        }

        let destinationURL = documentsDir.appendingPathComponent(
            url.lastPathComponent
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: url, to: destinationURL)
            print("녹음 파일 복사 성공 → \(destinationURL.path)")
            return destinationURL.path
        } catch {
            print("녹음 파일 복사 실패: \(error)")
            return nil
        }
    }

    // MARK: - 프로젝트 이름 생성
    private func generateProjectName(from url: URL) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return "녹음 \(formatter.string(from: Date()))"
    }

    // MARK: - 버튼 UI
    @ViewBuilder
    private func controls(
        status: RecordingFeature.Status,
        onStart: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) -> some View {
        switch status {
        case .ready:
            Button(action: onStart) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.black))
            }

        case .recording:
            HStack(spacing: 32) {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.black))
                }
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.red))
                }
            }

        case .paused:
            HStack(spacing: 32) {
                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.black))
                }
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.red))
                }
            }
            
        case .finishing:
            Button(action: {}) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.gray))
            }
            .disabled(true)
        }
    }
}
