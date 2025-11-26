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
    
    var body: some View {
        VStack {
            AudioDetailTabBar(selectedTab: $store.selectedTab)
            
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
                        Text("\(String(format: "%.1f", store.playbackRate))x") .font(.headline)
                    }
                    
                    Button (action:{ store.send(.backwardButtonTapped) }) {
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
    }
}

#Preview {
    AudioDetailView(
        store: Store(
            initialState:
                AudioDetailFeature.State(
                project:  Project(
                    id: UUID(), name: "10", creationDate: Calendar.current.date(
                        from: DateComponents(
                            year: 2025, month: 10, day: 16)
                    ) ?? Date(), category: .audio, isFavorite: false)
            )
        ) {
            AudioDetailFeature()
        }
    )
}
