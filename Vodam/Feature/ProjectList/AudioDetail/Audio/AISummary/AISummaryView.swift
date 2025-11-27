//
//  AISummaryView.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture

struct AISummaryView: View {
    let store: StoreOf<AISummaryFeature>
    
    var body: some View {
        Group {
            if store.isLoading {
                loadingView
            } else if let summary = store.summary {
                summaryContent(summary)
            } else {
                emptySummaryView
            }
        }
    }
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("AI가 요약 중입니다...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptySummaryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("AI 요약")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("스크립트를 AI로 요약합니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                store.send(.summarizeButtonTapped)
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("AI 요약하시겠습니까?")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func summaryContent(_ summary: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                    Text("AI 요약 완료")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button(action: {
                        store.send(.summarizeButtonTapped)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("다시 요약")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 8)
                
                Text(summary)
                    .font(.body)
                    .lineSpacing(6)
            }
            .padding()
        }
    }
}
