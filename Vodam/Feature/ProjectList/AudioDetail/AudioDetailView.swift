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
    @FocusState private var isSearchFieldFocused: Bool
    
    private var isPDF: Bool {
        store.project.category == .pdf
    }
    
    var body: some View {
        VStack {
            if store.isSearching {
                searchBarView
                    .transition(.push(from: .trailing))
            }
            
            AudioDetailTabBar(
                selectedTab: Binding(
                    get: { store.selectedTab },
                    set: { store.selectedTab = $0 }
                )
            )
            
            tabContent
            
            Spacer()
            
            bottomContent
        }
        .animation(.smooth(duration: 0.35), value: store.isSearching)
        .navigationTitle(store.isSearching ? "" : store.project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .navigationBarBackButtonHidden(store.isSearching)
        .onChange(of: store.isSearching) { _, isSearching in
            if isSearching {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isSearchFieldFocused = true
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
        .alert($store.scope(state: \.destination?.alert, action: \.destination.alert))
    }
    
    @ViewBuilder
    private var tabContent: some View {
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
    }
    
    @ViewBuilder
    private var bottomContent: some View {
        if !isPDF {
            audioPlayerControls
        } else {
            pdfInfoSection
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !store.isSearching {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation(.smooth(duration: 0.35)) {
                        _ = store.send(.searchButtonTapped)
                    }
                }) {
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
    }
    
    @ViewBuilder
    private var searchBarView: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.smooth(duration: 0.35)) {
                    _ = store.send(.searchCancelButtonTapped)
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
            
            searchField
            
            Button("취소") {
                withAnimation(.smooth(duration: 0.35)) {
                    _ = store.send(.searchCancelButtonTapped)
                }
            }
            .foregroundColor(.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - 검색 필드
    @ViewBuilder
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("검색", text: Binding(
                get: { store.searchText },
                set: { store.send(.searchTextChanged($0)) }
            ))
            .focused($isSearchFieldFocused)
            .submitLabel(.search)
            .onSubmit {
                store.send(.searchSubmitted)
            }
            
            // 검색 결과 표시 및 네비게이션
            if !store.searchText.isEmpty {
                searchResultsNavigation
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    @ViewBuilder
    private var searchResultsNavigation: some View {
        HStack(spacing: 4) {
            if store.script.totalResults > 0 {
                Text("\(store.script.currentResultNumber)/\(store.script.totalResults)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: { store.send(.script(.previousResult)) }) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: { store.send(.script(.nextResult)) }) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("결과 없음")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: { store.send(.searchTextChanged("")) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
    }
    
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
            
            playbackControls
        }
        .padding()
    }
    
    @ViewBuilder
    private var playbackControls: some View {
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
