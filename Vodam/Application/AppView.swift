//
//  AppView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI
import SwiftData
import AVFoundation

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    
    @Environment(\.modelContext) private var modelContext
    @Dependency(\.projectLocalDataClient) private var projectLocalDataClient
    @Dependency(\.firebaseClient) private var firebaseClient
    @Dependency(\.fileCloudClient) private var fileCloudClient

    var body: some View {
        TabView(selection: $store.startTab.sending(\.startTab)) {
            NavigationStack {
                MainView(
                    store: store.scope(state: \.main, action: \.main)
                )
            }
            .tabItem {
                Label("메인화면", systemImage: "house.fill")
            }
            .tag(AppFeature.State.Tab.main)

            NavigationStack {
                ProjectListView(
                    store: store.scope(state: \.list, action: \.list)
                )
            }
            .tabItem {
                Label("저장된 프로젝트", systemImage: "folder.fill")
            }
            .tag(AppFeature.State.Tab.list)

            NavigationStack {
                ChattingListView(
                    store: store.scope(state: \.chat, action: \.chat)
                )
            }
            .tabItem {
                Label("채팅", systemImage: "message.badge.waveform.fill")
            }
            .tag(AppFeature.State.Tab.chat)
        }
        // ✅ 탭 전환 시 AVAudioSession 정리
        .onChange(of: store.startTab) { oldTab, newTab in
            print("[AppView] 탭 전환: \(oldTab) → \(newTab)")
            
            // 메인 탭으로 전환할 때 (녹음할 수 있는 탭)
            if newTab == .main {
                cleanupAudioSession()
            }
        }
        .onChange(of: store.user) { oldValue, newValue in
            // 사용자 변경 시 Firebase 동기화 (어느 탭에서든 실행됨)
            if oldValue?.ownerId != newValue?.ownerId {
                FirebaseSyncHelper.handleUserChange(
                    oldValue: oldValue,
                    newValue: newValue,
                    modelContext: modelContext,
                    projectLocalDataClient: projectLocalDataClient,
                    firebaseClient: firebaseClient,
                    fileCloudClient: fileCloudClient,
                    onComplete: {
                        store.send(.list(.refreshProjects))
                    }
                )
            }
        }
    }
    
    // ✅ AVAudioSession 정리 함수
    private func cleanupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // 현재 카테고리 확인
            let currentCategory = session.category
            print("[AppView] 현재 AVAudioSession 카테고리: \(currentCategory)")
            
            // playback 모드였다면 비활성화
            if currentCategory == .playback {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
                print("[AppView] ✅ AVAudioSession 비활성화 완료")
            }
            
            // 녹음을 위해 record 카테고리로 준비 (options 없이)
            try session.setCategory(.record, mode: .default, options: [])
            print("[AppView] ✅ AVAudioSession을 record 모드로 설정")
            
        } catch {
            print("[AppView] ⚠️ AVAudioSession 정리 실패: \(error)")
        }
    }
}
