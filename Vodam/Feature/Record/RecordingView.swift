//
//  RecordingView.swift
//  VoDam
//

import SwiftUI
import ComposableArchitecture
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var context
    @State private var showTitleSheet: Bool = false
    @State private var inputTitle: String = ""

    @Bindable var store: StoreOf<RecordingFeature>

    init(store: StoreOf<RecordingFeature>) {
        self.store = store
    }

    var body: some View {
        WithPerceptionTracking {
            mainContent
                .onChange(of: store.fileURL) { newURL in
                    guard newURL != nil else { return }
                    prepareDefaultTitle()
                }
                .sheet(isPresented: $showTitleSheet) {
                    RecordingSaveSheet(
                        title: $inputTitle,
                        onCancel: { showTitleSheet = false },
                        onSave: {
                            saveRecording(
                                url: store.fileURL,
                                length: store.lastRecordedLength
                            )
                        }
                    )
                }
        }
    }

    // MARK: - 메인 녹음 UI
    private var mainContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)

            VStack(spacing: 24) {
                controls(for: store.status)

                RecordingStatusView(
                    title: store.status.localizedText,
                    formattedTime: formatTime(store.elapsedSeconds)
                )
            }
            .padding(.vertical, 40)
        }
        .frame(height: 240)
        .padding(.horizontal, 20)
    }

    // MARK: - SwiftData 저장 준비
    private func prepareDefaultTitle() {
        Task { @MainActor in
            do {
                let descriptor = FetchDescriptor<RecordingModel>()
                let count = try context.fetchCount(descriptor)
                inputTitle = "음성 녹음 \(count + 1)"
            } catch {
                inputTitle = "음성 녹음"
            }
            showTitleSheet = true
        }
    }

    // MARK: - SwiftData 저장
    private func saveRecording(url: URL?, length: Int) {
        guard let url else { return }

        let model = RecordingModel(
            filename: inputTitle.isEmpty ? url.lastPathComponent : inputTitle,
            filePath: url.path,
            length: length,
            createdAt: .now
        )

        context.insert(model)
        do {
            try context.save()
            print("💾 SwiftData 저장 완료: \(model.filename)")
        } catch {
            print("❌ SwiftData 저장 실패: \(error)")
        }

        showTitleSheet = false
    }

    // MARK: - 버튼 UI
    @ViewBuilder
    private func controls(for status: RecordingFeature.Status) -> some View {
        switch status {
        case .ready:
            controlButton(
                systemName: "mic.fill",
                backgroundColor: .black,
                action: { store.send(.startTapped) }
            )

        case .recording:
            HStack(spacing: 32) {
                controlButton(
                    systemName: "pause.fill",
                    backgroundColor: .black,
                    action: { store.send(.pauseTapped) }
                )
                controlButton(
                    systemName: "stop.fill",
                    backgroundColor: .red,
                    action: { store.send(.stopTapped) }
                )
            }

        case .paused:
            HStack(spacing: 32) {
                controlButton(
                    systemName: "play.fill",
                    backgroundColor: .black,
                    action: { store.send(.startTapped) }
                )
                controlButton(
                    systemName: "stop.fill",
                    backgroundColor: .red,
                    action: { store.send(.stopTapped) }
                )
            }
        }
    }

    private func controlButton(
        systemName: String,
        backgroundColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(backgroundColor))
        }
    }

    // MARK: - 시간 포맷
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainderSeconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, remainderSeconds)
    }
}

private struct RecordingStatusView: View {
    let title: String
    let formattedTime: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)

            Text(formattedTime)
                .font(.system(size: 32, weight: .medium))
                .monospacedDigit()
        }
    }
}

private struct RecordingSaveSheet: View {
    @Binding var title: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("파일 제목 입력")
                .font(.headline)

            TextField("녹음 제목", text: $title)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("취소") {
                    onCancel()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.black)
                .cornerRadius(10)

                Button(action: onSave) {
                    Text("저장")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.bottom, 16)
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
    }
}
