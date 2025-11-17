//
//  MainView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct MainView: View { //MainView에서 사용하는 store 객체는 MainFeature
    let store: StoreOf<MainFeature>  // MainFeature.Action

    var body: some View {
        VStack { // 화면 세로 배치, 항상 가운데 정렬

            Text("여기에 메인 UI 들어갈 예정")
                .font(.title3)
                .foregroundStyle(.secondary)

        }
        .navigationTitle("새 프로젝트 생성") //네비게이션 상단 제목
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { //toolbar/toolbaritem
                Button {
                    store.send(.profileButtonTapped) //Button 탭을 store 전달
                } label: {
                    Image(systemName: "person.circle")
                        .imageScale(.large)
                }
            }
        }

        .navigationDestination(
            store: store.scope( // 특정 상태가 존재할 때 다음 화면으로 이동하게 하는 TCA 문법
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
