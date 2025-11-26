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
    
    private func handleUserChange(oldValue: User?, newValue: User?) {
        guard let user = newValue else { return }
        
        let ownerId = user.ownerId
        
        Task {
            do {
                // 1) 게스트 프로젝트 → 로그인 사용자로 마이그레이션
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
                
                // 3) 항상 Firebase에서 최신 프로젝트 리스트 내려받기
                let remoteProjects = try await firebaseClient.fetchProjects(ownerId)
                print(
                    "Firebase에서 \(remoteProjects.count)개 프로젝트 가져옴 (ownerId: \(ownerId))"
                )
                
                // 4) Firebase → SwiftData 동기화
                try syncRemoteProjectsToLocal(remoteProjects, ownerId: ownerId)
                
            } catch {
                print("로그인 후 Firebase 동기화 실패: \(error)")
            }
        }
    }
    
    private func syncRemoteProjectsToLocal(
        _ remoteProjects: [ProjectPayload],
        ownerId: String
    ) throws {
        let descriptor = FetchDescriptor<ProjectModel>(
            predicate: #Predicate { project in
                project.ownerId == ownerId
            }
        )
        
        let existingModels = try modelContext.fetch(descriptor)
        let existingById = Dictionary(
            uniqueKeysWithValues: existingModels.map { ($0.id, $0) }
        )
        
        for payload in remoteProjects {
            if let existing = existingById[payload.id] {
                existing.name = payload.name
                existing.creationDate = payload.creationDate
                existing.category = payload.category
                existing.isFavorite = payload.isFavorite
                existing.filePath = payload.filePath
                existing.fileLength = payload.fileLength
                existing.transcript = payload.transcript
                existing.syncStatus = .synced
            } else {
                let model = ProjectModel(
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
                
                modelContext.insert(model)
            }
        }
        
        try modelContext.save()
        print(
            "[MainView] Firebase → SwiftData 동기화 완료: \(remoteProjects.count)개 upsert (ownerId: \(ownerId))"
        )
    }
}
