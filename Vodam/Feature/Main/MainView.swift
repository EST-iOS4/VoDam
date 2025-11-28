//
//  MainView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftData
import SwiftUI

struct MainView: View {
    @Bindable var store: StoreOf<MainFeature>
    
    @Environment(\.modelContext) private var modelContext
    @Dependency(\.projectLocalDataClient) private var projectLocalDataClient
    @Dependency(\.firebaseClient) private var firebaseClient
    @Dependency(\.fileCloudClient) private var fileCloudClient
    
    init(store: StoreOf<MainFeature>) {
        self.store = store
    }
    
    var body: some View {
        contentView
            .navigationTitle("새 프로젝트 생성")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    profileButton
                }
            }
            .navigationDestination(
                store: store.scope(
                    state: \.$loginProviders,
                    action: \.loginProviders
                )
            ) { loginProvidersStore in
                LoginProvidersView(store: loginProvidersStore)
            }
            .sheet(
                store: store.scope(
                    state: \.$profileFlow,
                    action: \.profileFlow
                )
            ) { profileStore in
                profileSheetContent(profileStore)
            }
            .navigationDestination(
                store: store.scope(
                    state: \.$settings,
                    action: \.settings
                )
            ) { settingStore in
                SettingView(store: settingStore)
            }
            .onAppear {
                store.send(.onAppear)
            }
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        VStack {
            RecordingView(
                store: store.scope(
                    state: \.recording,
                    action: \.recording
                ),
                ownerId: store.currentUser?.ownerId
            )
            
            FileButtonView(
                store: store.scope(
                    state: \.fileButton,
                    action: \.fileButton
                ),
                ownerId: store.currentUser?.ownerId
            )
            
            PDFButtonView(
                store: store.scope(
                    state: \.pdfButton,
                    action: \.pdfButton
                )
            )
            
            Spacer()
        }
    }
    
    // MARK: - Profile Button
    @ViewBuilder
    private var profileButton: some View {
        Button {
            store.send(.profileButtonTapped)
        } label: {
            if store.currentUser != nil {
                ProfileImageView(
                    user: store.currentUser,
                    size: 36,
                    cornerRadius: 18,
                    showEditButton: false
                )
            } else {
                Image(systemName: "person.circle")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Profile Sheet Content
    @ViewBuilder
    private func profileSheetContent(
        _ profileStore: StoreOf<ProfileFlowFeature>
    ) -> some View {
        ProfileFlowView(store: profileStore)
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.visible)
    }
}
