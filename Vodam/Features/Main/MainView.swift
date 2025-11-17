//
//  MainView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//
import ComposableArchitecture
import SwiftUI


// MARK: view
struct MainView: View {
    // MARK: model
    @State var store: StoreOf<MainFeature>

    
    // MARK: body
    var body: some View {
        VStack {
            Spacer()

            Text("여기에 메인 UI 들어갈 예정")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .navigationTitle("새 프로젝트 생성")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.send(.goToProfile)
                } label: {
                    Image(systemName: "person.circle")
                        .imageScale(.large)
                }
            }
        }
        
        .navigationDestination(
            item: $store.scope(state: \.destination?.loginProvider, action: \.destionation.loginProvider), destination: { store in
                LoginProvidersView(store: store)
            })
        
        // 로그인 유도 sheet
        .sheet(
            item: $store.scope(state: \.destination?.profile, action: \.destionation.profile)
        ) { profileStore in
            ProfileFlowView(store: profileStore)
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
        }
    }
}
