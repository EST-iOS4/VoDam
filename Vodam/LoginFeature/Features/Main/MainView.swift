//
//  MainView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct MainView: View {
    let store: StoreOf<MainFeature>  // MacinFeature.Action

    var body: some View {
        VStack {

            Text("여기에 메인 UI 들어갈 예정")
                .font(.title3)
                .foregroundStyle(.secondary)

        }
        .navigationTitle("새 프로젝트 생성")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.send(.profileButtonTapped)
                } label: {
                    Image(systemName: "person.circle")
                        .imageScale(.large)
                }
            }
        }

        .navigationDestination(
            store: store.scope(
                state: \.$loginProviders,
                action: \.loginProviders
            )
        ) {
            loginProvidersStore in
            LoginProvidersView(store: loginProvidersStore)
        }
        // 로그인 유도 sheet
        .sheet(
            store: store.scope(
                state: \.$profileFlow,
                action: \.profileFlow
            )
        ) { profileStore in
            ProfileFlowView(store: profileStore)
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
        }
    }
}
