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

    @Dependency(\.recordingLocalDataClient) var recordingLocalDataClient
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
        .frame(height: 240)
        .padding(.horizontal, 20)
    }

    // MARK: - SwiftData 저장
    private func saveToSwiftData(url: URL, length: Int) {
        do {
            let playload = try recordingLocalDataClient.save(
                context,
                url,
                length,
                ownerId
            )

            if let ownerId {
                Task {
                    do {
                        try await firebaseClient.uploadRecordings(
                            ownerId,
                            [playload]
                        )
                        print(
                            "Firebase 업로드 성공 → ownerId: \(ownerId), id: \(playload.id)"
                        )
                    } catch {
                        print("Firebase 업로드 실패: \(error)")
                    }
                }
            } else {
                // 비회원(게스트) 저장
                print("비회원 모드: Firebase 업로드 생략 (ownerId = nil)")
            }
        } catch {
            print("SwiftData 저장 실패: \(error)")
        }

//        showTitleSheet = false
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
