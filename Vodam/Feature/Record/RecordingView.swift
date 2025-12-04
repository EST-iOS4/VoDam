//
//  RecordingView.swift
//  VoDam
//

import ComposableArchitecture
import SwiftUI

struct RecordingView: View {
    let store: StoreOf<RecordingFeature>
    let ownerId: String?
    
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    
    @State private var isGuestLimitAlertPresented = false
    
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
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            
            VStack(spacing: 24) {
                
                controls(
                    status: store.status,
                    onStart: { handleStartTapped() },
                    onPause: { store.send(.pauseTapped) },
                    onStop: { store.send(.stopTapped) }
                )
                
                Text(store.status.localizedText)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(formatTime(store.elapsedSeconds))
                    .font(.system(size: 32, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 40)
        }
        .frame(height: 240)
        .padding(.horizontal, 20)
        
        .onChange(of: store.fileURL) { _, newValue in
            if let url = newValue, store.status == .finishing {
                store.send(.saveRecording(url, store.lastRecordedLength, ownerId))
            }
        }
        .alert(
            "게스트는 녹음을 최대 3개까지 저장할 수 있습니다.",
            isPresented: $isGuestLimitAlertPresented
        ) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("기존 녹음을 삭제하거나 로그인 후 이용해주세요.")
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
                    .foregroundColor(Color(.systemBackground))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.primary))
            }
            
        case .recording:
            HStack(spacing: 32) {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .foregroundColor(Color(.systemBackground))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.primary))
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
                        .foregroundColor(Color(.systemBackground))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.primary))
                }
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.red))
                }
            }
            
        case .finishing:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                .frame(width: 56, height: 56)
        }
    }
    
    // MARK: - 시간 포맷
    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    private func handleStartTapped() {
        if ownerId != nil {
            store.send(.startTapped)
            return
        }

        Task {
            do {
                let allProjects = try await projectLocalDataClient.fetchAll(nil)
                let guestAudioProjects = allProjects.filter { $0.category == .audio }
                
                if guestAudioProjects.count >= 3 {
                    _ = await MainActor.run {
                        isGuestLimitAlertPresented = true
                    }
                    return
                }
            } catch {
                print("[RecordingView] 프로젝트 조회 실패: \(error)")
            }
            
           _ = await MainActor.run {
                store.send(.startTapped)
            }
        }
    }
}
