//
//  RecordingView.swift
//  VoDam
//

import ComposableArchitecture
import SwiftData
import SwiftUI

struct RecordingView: View {
    @Environment(\.modelContext) var context  // SwiftData ModelContext
    let store: StoreOf<RecordingFeature>

    let ownerId: String?

    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient

    init(
        store: StoreOf<RecordingFeature>,
        ownerId: String?
    ) {
        self.store = store
        self.ownerId = ownerId
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)

            VStack(spacing: 24) {

                // 상태별 버튼
                controls(
                    status: store.status,
                    onStart: { store.send(.startTapped) },
                    onPause: { store.send(.pauseTapped) },
                    onStop: { store.send(.stopTapped) }
                )

                // 상태 텍스트
                Text(store.status.localizedText)
                    .font(.headline)

                // 녹음 시간 표시
                Text(store.elapsedSeconds.formattedTime)
                    .font(.system(size: 32, weight: .medium))
                    .monospacedDigit()
            }
            .padding(.vertical, 40)
        }
        .frame(height: 240)
        .padding(.horizontal, 20)

        // MARK: - 🔥 fileURL 변경 감지 → SwiftData 저장
        .onChange(of: store.fileURL) { _, newValue in
            guard let url = newValue else { return }
            saveToSwiftData(url: url, length: store.lastRecordedLength)
        }
    }

    // MARK: - SwiftData 저장
    private func saveToSwiftData(url: URL, length: Int) {
        do {
            guard let storedPath = copyRecordedFileToDocuments(url: url) else {
                        print("녹음 파일 복사 실패 – 프로젝트 저장 중단")
                        return
                    }

            let projectName = generateProjectName(from: url)

            let payload = try projectLocalDataClient.save(
                context,
                projectName,
                .audio,
                storedPath,
                length,
                nil,
                ownerId
            )

            print("프로젝트 저장 성공 → \(payload.name), id: \(payload.id)")

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

                        try await firebaseClient.uploadProjects(
                            ownerId,
                            [syncedPayload]
                        )

                        try projectLocalDataClient.updateSyncStatus(
                            context,
                            [payload.id],
                            .synced,
                            ownerId
                        )
                        print(
                            "Firebase 업로드 성공 → ownerId: \(ownerId), id: \(payload.id)"
                        )
                    } catch {
                        print("Firebase 업로드 실패: \(error)")
                    }
                }
            } else {
                // 비회원(게스트) 저장
                print("비회원 모드: Firebase 업로드 생략 (ownerId = nil)")
            }
            store.send(.recordingSaved(payload.id))
        } catch {
            print("프로젝트 저장 실패: \(error)")
            store.send(.recordingSaveFailed(error.localizedDescription))
        }
    }

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
        }
    }

    // MARK: - 시간 포맷
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
