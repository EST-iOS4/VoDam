//
//  RecordingView.swift
//  VoDam
//

import ComposableArchitecture
import SwiftData
import SwiftUI

struct RecordingView: View {
    @Environment(\.modelContext) var modelContext
    let store: StoreOf<RecordingFeature>

    let ownerId: String?
    let showLiveTranscript: Bool

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

        // STT 완료 후 저장 (finalTranscript가 설정되면)
        .onChange(of: store.finalTranscript) { _, _ in
            guard let url = store.fileURL,
                  store.status == .ready else { return }
            store.send(.saveRecording(url, store.lastRecordedLength, ownerId, modelContext))
        }
        // transcript 없이 저장되는 경우 (STT 실패 등)
        .onChange(of: store.status) { oldStatus, newStatus in
            guard oldStatus == .finishing,
                  newStatus == .ready,
                  let url = store.fileURL else { return }
            
            // finalTranscript onChange가 이미 처리했으면 스킵
            if store.finalTranscript == nil {
                store.send(.saveRecording(url, store.lastRecordedLength, ownerId, modelContext))
            }
        }
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
