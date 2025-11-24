//
//  AppView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        WithPerceptionTracking {
            TabView(selection: $store.startTab.sending(\.startTab)) {
                NavigationStack {
                    MainView(
                        store: store.scope(state: \.main, action: \.main)
                    )
                    .id(store.main.currentUser?.email ?? "guest")
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
        }
    }

}
