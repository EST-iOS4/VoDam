//
//  AudioDetailView.swift
//  Vodam
//
//  Created by 서정원 on 11/18/25.
//

import ComposableArchitecture
import SwiftUI

struct AudioDetailView: View {
    @Bindable var store: StoreOf<AudioDetailFeature>
    
    // PDF 확인
    private var isPDF: Bool {
        store.project.category == .pdf
    }
    
    var body: some View {
        VStack {
            AudioDetailTabBar(
                selectedTab: Binding(
                    get: { store.selectedTab },
                    set: { store.selectedTab = $0 }
                )
            )
            
            switch store.selectedTab {
            case .aiSummary:
                AISummaryView(
                    store: store.scope(
                        state: \.aiSummary, action: \.aiSummary
                    )
                )
            case .script:
                ScriptView(
                    store: store.scope(
                        state: \.script, action: \.script
                    )
                )
            }
            
            Spacer()
            
            // PDF가 아닐 때만 재생 컨트롤 표시
            if !isPDF {
                audioPlayerControls
            } else {
                pdfInfoSection
            }
        }
        .navigationTitle(store.project.name)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { store.send(.searchButtonTapped) }) {
                    Image(systemName: "magnifyingglass")
                }
                
                Button(action: { store.send(.chatButtonTapped) }) {
                    Image(systemName: "message")
                }
                
                Menu {
                    Button(action: {  }) {
                        Label("제목 수정", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        store.send(.deleteProjectButtonTapped)
                    } label: {
                        Label("삭제", systemImage: "xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    }
    
    // MARK: 오디오만 컨트롤
    @ViewBuilder
    private var audioPlayerControls: some View {
        VStack(spacing: 20) {
            Slider(value: $store.progress.sending(\.seek))
                .padding(.horizontal)
            
            HStack {
                Text(store.currentTime)
                Spacer()
                Text(store.totalTime)
            }
            .padding(.horizontal)
            
            HStack(spacing: 40) {
                Menu {
                    Button("1.0x", action: { store.send(.setPlaybackRate(1.0)) })
                    Button("1.5x", action: { store.send(.setPlaybackRate(1.5)) })
                    Button("2.0x", action: { store.send(.setPlaybackRate(2.0)) })
                } label: {
                    Text("\(String(format: "%.1f", store.playbackRate))x")
                        .font(.headline)
                }
                
                Button(action: { store.send(.backwardButtonTapped) }) {
                    Image(systemName: "gobackward.10")
                        .font(.title)
                }
                
                Button(action: { store.send(.playButtonTapped) }) {
                    Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }
                
                Button(action: { store.send(.forwardButtonTapped) }) {
                    Image(systemName: "goforward.10")
                        .font(.title)
                }
                
                Button(action: { store.send(.favoriteButtonTapped) }) {
                    Image(systemName: store.isFavorite ? "star.fill" : "star")
                        .font(.title)
                }
            }
            .padding(.bottom)
        }
        .padding()
    }
    
    //pdf 만
    @ViewBuilder
    private var pdfInfoSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("PDF 문서")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button(action: { store.send(.favoriteButtonTapped) }) {
                HStack {
                    Image(systemName: store.isFavorite ? "star.fill" : "star")
                        .font(.title2)
                    Text(store.isFavorite ? "즐겨찾기에서 제거" : "즐겨찾기에 추가")
                }
                .foregroundColor(.blue)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
