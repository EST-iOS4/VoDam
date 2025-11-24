//
//  MainView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct MainView: View {
    @Bindable var store: StoreOf<MainFeature>

    init(store: StoreOf<MainFeature>) {
        self.store = store
    }

    var body: some View {
        VStack {
            RecordingView( // RecordingView stae, action을 store
                store: store.scope(
                    state: \.recording,
                    action: \.recording
                )
            )
            FileButtonView(
                store: store.scope(
                    state: \.fileButton,
                    action: \.fileButton
                )
            )
            
            PDFButtonView(
                store: store.scope(
                    state: \.pdfButton,
                    action: \.pdfButton
                )
            )
            Spacer()
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

        .navigationDestination(
            store: store.scope(
                state: \.$settings,
                action: \.settings
            )
        ) {
            settingStore in
            SettingView(store: settingStore)
        }
    }
}
