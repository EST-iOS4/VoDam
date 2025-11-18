//
//  MainView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct MainView: View {
    let store: StoreOf<MainFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                Spacer()

                Text("여기에 메인 UI 들어갈 예정")
                    .font(AppConfig.pretendardExtraBold(size: 30))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .navigationTitle("새 프로젝트 생성")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewStore.send(.profileButtonTapped)
                    } label: {
                        Image(systemName: "person.circle")
                            .imageScale(.large)
                    }
                }
            }
            .navigationDestination(
                isPresented: viewStore.binding(
                    get: \.isLoginProvidersActive,
                    send: MainFeature.Action.loginProvidersActiveChanged
                )
            ) {
                LoginProvidersView(
                    store: store.scope(
                        state: \.loginProviders,
                        action: \.loginProviders
                    )
                )
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
}
