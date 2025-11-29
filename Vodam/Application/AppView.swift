//
//  AppView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI
import SwiftData

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
}
