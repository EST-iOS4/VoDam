//
//  RecordingButton.swift
//  VoDam
//
//  Created by 강지원 on 11/18/25.
//

import SwiftUI
import ComposableArchitecture

struct RecordingView: View {
    let store: StoreOf<RecordingFeature>

    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)

                VStack(spacing: 24) {
                    // 상태 텍스트
                    Text(viewStore.status.localizedText)
                        .font(.headline)

                    // 상태별 버튼
                    controls(
                        status: viewStore.status,
                        onStart: { viewStore.send(.startTapped) },
                        onPause: { viewStore.send(.pauseTapped) },
                        onStop: { viewStore.send(.stopTapped) }
                    )
                    
                    // 녹음 시간 표시
                    Text(formatTime(viewStore.elapsedSeconds))
                        .font(.system(size: 32, weight: .medium))
                        .monospacedDigit()
                }
                .padding(.vertical, 40)
            }
            .frame(height: 240)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - 상태별 버튼 UI
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
                        .background(Circle().fill(Color.blue))
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
                        .background(Circle().fill(Color.blue))
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

    // MARK: - 시간 포맷 (초 → 00:00)
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
