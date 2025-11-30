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
                    .foregroundColor(.black)
                
                // 녹음 시간 표시
                Text(formatTime(store.elapsedSeconds))
                    .font(.system(size: 32, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.black)
            }
            .padding(.vertical, 40)
        }
        .frame(height: 240)
        .padding(.horizontal, 20)
        
        .onChange(of: store.fileURL) { _, newValue in
            guard let url = newValue else { return }
            store.send(.saveRecording(url, store.lastRecordedLength, ownerId, modelContext))
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
