//
//  AISummaryView.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture
import SwiftData

struct AISummaryView: View {
    let store: StoreOf<AISummaryFeature>
    
    var body: some View {
        Group {
            if store.isLoading && (store.summary == nil || store.progress < 1.0) {
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
            ProgressView(value: store.progress)
                .progressViewStyle(.linear)
                .padding(.horizontal, 40)
            
            Text(store.progressMessage ?? "AI가 요약 중입니다...")
                .font(AppFont.pretendardSemiBold(size: 17))
                .foregroundColor(.secondary)
            
            Text("\(Int(store.progress * 100))%")
                .font( AppFont.pretendardBold(size: 22) )
                .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptySummaryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(AppFont.pretendardRegular(size: 60))
                .foregroundColor(.blue)
            
            Text("AI 요약")
                .font(AppFont.pretendardBold(size: 22))
            
            Text("스크립트를 AI로 요약합니다")
                .font(AppFont.pretendardRegular(size: 15))
                .foregroundColor(.secondary)
            
            Button(action: {
                store.send(.summarizeButtonTapped)
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("AI 요약하시겠습니까?")
                }
                .font(AppFont.pretendardSemiBold(size: 17))
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
                        .foregroundColor(.yellow)
                    Text("AI 요약 완료")
                        .font(AppFont.pretendardSemiBold(size: 17))
                        .foregroundColor(AppColor.mainColor)
                    
                    Spacer()
                    
                    Button(action: {
                        store.send(.summarizeButtonTapped)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("다시 요약")
                        }
                        .font(AppFont.pretendardRegular(size: 12))
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)
                
                MarkdownTextView(summary, font: AppFont.pretendardRegular(size: 17), linSpacing: 6)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
            }
            .padding()
        }
    }
}
