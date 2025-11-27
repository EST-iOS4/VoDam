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
    @Dependency(\.audioCloudClient) private var audioCloudClient
    
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
                
                if migratedProjects.isEmpty {
                    print("마이그레이션 대상 게스트 프로젝트 없음")
                } else {
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
                    try await firebaseClient.uploadProjects(ownerId, syncedPayloads)
                    
                    let ids = syncedPayloads.map(\.id)
                    
                    try projectLocalDataClient.updateSyncStatus(
                        modelContext,
                        ids,
                        .synced,
                        ownerId
                    )
                    
                    print(
                        "게스트 프로젝트 \(migratedProjects.count)개 마이그레이션 및 Firebase 동기화 완료"
                    )
                }
                
                let remoteProjects = try await firebaseClient.fetchProjects(ownerId)
                print(
                    "Firebase에서 \(remoteProjects.count)개 프로젝트 가져옴 (ownerId: \(ownerId))"
                )
                
                try await syncRemoteProjectsToLocal(remoteProjects, ownerId: ownerId)
                
            } catch {
                print("로그인 후 Firebase 동기화 실패: \(error)")
            }
        }
    }
    
    private func syncRemoteProjectsToLocal(
        _ remoteProjects: [ProjectPayload],
        ownerId: String
    ) async throws {
        let descriptor = FetchDescriptor<ProjectModel>(
            predicate: #Predicate { project in
                project.ownerId == ownerId
            }
        )

        let existingModels = try modelContext.fetch(descriptor)
        var existingById = Dictionary(
            uniqueKeysWithValues: existingModels.map { ($0.id, $0) }
        )

        for payload in remoteProjects {
            let model: ProjectModel
            if let existing = existingById[payload.id] {
                model = existing
                model.name = payload.name
                model.creationDate = payload.creationDate
                model.category = payload.category
                model.isFavorite = payload.isFavorite
                model.filePath = payload.filePath
                model.fileLength = payload.fileLength
                model.transcript = payload.transcript
                model.syncStatus = .synced
            } else {
                model = ProjectModel(
                    id: payload.id,
                    name: payload.name,
                    creationDate: payload.creationDate,
                    category: payload.category,
                    isFavorite: payload.isFavorite,
                    filePath: payload.filePath,
                    fileLength: payload.fileLength,
                    transcript: payload.transcript,
                    ownerId: ownerId,
                    syncStatus: .synced,
                    remoteAudioPath: payload.remoteAudioPath
                )
                modelContext.insert(model)
                existingById[payload.id] = model
            }

            if
                payload.category == .audio,
                let remotePath = payload.remoteAudioPath
            {
                let currentLocalPath = model.filePath

                let newLocalPath = try await audioCloudClient.downloadAudioIfNeeded(
                    ownerId,
                    payload.id,
                    remotePath,
                    currentLocalPath
                )

                model.filePath = newLocalPath
                model.remoteAudioPath = remotePath
                model.syncStatus = .synced
            }
        }

        try modelContext.save()
        print("[MainView] Firebase + Storage → SwiftData 동기화 완료: \(remoteProjects.count)개 upsert")
    }
}
