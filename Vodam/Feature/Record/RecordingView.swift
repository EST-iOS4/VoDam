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

    let store: StoreOf<RecordingFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ZStack {
                // 메인 녹음 카드
                mainContent(viewStore)
            }
            .onChange(of: viewStore.state.fileURL) { newURL in
                guard newURL != nil else { return }

                // 🔥 SwiftData에 있는 녹음 개수 기반으로 기본 제목 생성
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
            .sheet(isPresented: $showTitleSheet) {
                VStack(spacing: 24) {
                    Capsule()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 40, height: 5)
                        .padding(.top, 8)

                    Text("파일 제목 입력")
                        .font(.headline)

                    TextField("녹음 제목", text: $inputTitle)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        Button("취소") {
                            showTitleSheet = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.black)
                        .cornerRadius(10)

                        Button {
                            saveRecording(
                                url: viewStore.state.fileURL,
                                length: viewStore.state.lastRecordedLength
                            )
                        } label: {
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
    }

    // MARK: - 메인 녹음 UI
    private func mainContent(_ viewStore: ViewStore<RecordingFeature.State, RecordingFeature.Action>) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)

            VStack(spacing: 24) {
                controls(
                    status: viewStore.state.status,
                    onStart: { viewStore.send(.startTapped) },
                    onPause: { viewStore.send(.pauseTapped) },
                    onStop: { viewStore.send(.stopTapped) }
                )

                Text(viewStore.state.status.localizedText)
                    .font(.headline)

                Text(formatTime(viewStore.state.elapsedSeconds))
                    .font(.system(size: 32, weight: .medium))
                    .monospacedDigit()
            }
            .padding(.vertical, 40)
        }
        .frame(height: 240)
        .padding(.horizontal, 20)
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
