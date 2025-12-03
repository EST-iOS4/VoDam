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
        .onChange(of: store.startTab) { oldTab, newTab in
            print("[AppView] 탭 전환: \(oldTab) → \(newTab)")
            
            if newTab == .main {
                cleanupAudioSession()
            }
        }
        .onChange(of: store.user) { oldValue, newValue in
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
    
    private func cleanupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            let currentCategory = session.category
            print("[AppView] 현재 AVAudioSession 카테고리: \(currentCategory)")
            
            if currentCategory == .playback {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
                print("[AppView] ✅ AVAudioSession 비활성화 완료")
            }
            
            try session.setCategory(.record, mode: .default, options: [])
            print("[AppView] ✅ AVAudioSession을 record 모드로 설정")
            
        } catch {
            print("[AppView] ⚠️ AVAudioSession 정리 실패: \(error)")
        }
    }
}
