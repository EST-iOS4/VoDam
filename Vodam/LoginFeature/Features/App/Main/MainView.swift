//
//  MainView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct MainView: View {
    // main 하 는 상태오 리듀서(액션)
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

        //.navigationDestinaton(store:)
        .navigationDestination(
            store: store.scope(
                state: \.$loginProviders,
                action: \.loginProviders
            )
        ) {
            loginProvidersStore in
            LoginProvidersView(store: loginProvidersStore)
        }
        
        //.sheet(store:)          .sheet(ispresented: )대신에 store에 상태를 바탕으로 시트를 구현해주는 모디파이어? 같은거죠. //nil 아닐때 만얘가 활성화가죠.
        // 로그인 유도 sheet
        .sheet(
            store: store.scope(
                //$가 인스터스를 가지고있는지, nil,falase,true이 bool값 처럼 트리거역할)
                state: \.$profileFlow,
                action: \.profileFlow
            )
        ) { profileStore in
            ProfileFlowView(store: profileStore) //여기서 뷰가 그려지는 거다.
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
        }
    }
}
