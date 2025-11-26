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
            .onChange(of: store.currentUser) { oldValue, newValue in
                handleUserChange(oldValue: oldValue, newValue: newValue)
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

    // MARK: - User Change Handler
    private func handleUserChange(oldValue: User?, newValue: User?) {
        guard let user = newValue else { return }

        let ownerId = user.ownerId

        Task {
            do {
                let migratedProjects =
                    try projectLocalDataClient.migrateGuestProjects(
                        modelContext,
                        ownerId
                    )

                guard !migratedProjects.isEmpty else {
                    print("ℹ️ 마이그레이션 대상 게스트 프로젝트 없음")
                    return
                }

                print("마이그레이션 대상 게스트 프로젝트: \(migratedProjects.count)")

                let syncedPayloads = migratedProjects.map { payload in
                    ProjectPayload(
                        id: payload.id,
                        name: payload.name,
                        creationDate: payload.creationDate,
                        category: payload.category,
                        isFavorite: payload.isFavorite,
                        filePath: payload.filePath,
                        fileLength: payload.fileLength,
                        transcript: payload.transcript,
                        ownerId: ownerId,
                        syncStatus: .synced
                    )
                }

                try await firebaseClient.uploadProjects(ownerId, syncedPayloads)

                // SwiftData의 syncStatus 업데이트
                let ids = migratedProjects.map { $0.id }
                try projectLocalDataClient.updateSyncStatus(
                    modelContext,
                    ids,
                    .synced,
                    ownerId
                )

                print(
                    "✅ 게스트 프로젝트 \(migratedProjects.count)개 마이그레이션 및 Firebase 동기화 완료"
                )

            } catch {
                print("❌ 게스트 → 로그인 마이그레이션 실패: \(error)")
            }
        }
    }
}
