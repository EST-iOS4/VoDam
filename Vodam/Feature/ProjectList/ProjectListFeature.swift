//
// ProjectListView.swift
// Vodam
//
// Created by 서정원 on 11/17/25.
//

import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct ProjectListFeature {
    
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient
    @Dependency(\.fileCloudClient) var fileCloudClient
    
    @ObservableState
    struct State: Equatable {
        var projects: IdentifiedArrayOf<Project> = []
        var isLoading = false
        var hasLoadedOnce = false
        var refreshTrigger: UUID? = nil
        var allCategories: [FilterCategory] = FilterCategory.allCases
        var selectedCategory: FilterCategory = .all
        var currentSort: SortFilter = .sortedDate
        var searchText: String = ""
        var isFavorite = false
        
        // 현재 사용자 (AppFeature에서 전달)
        var currentUser: User? = nil
        
        @Presents var destination: Destination.State?
        
        var projectState: IdentifiedArrayOf<Project> {
            var filtered = projects
            
            if let selectedProjectCategory = selectedCategory.projectCategory {
                filtered = filtered.filter {
                    $0.category == selectedProjectCategory
                }
            }
            
            if !searchText.isEmpty {
                filtered = filtered.filter {
                    $0.name.localizedCaseInsensitiveContains(searchText)
                }
            }
            
            filtered.sort { p1, p2 in
                if p1.isFavorite != p2.isFavorite {
                    return p1.isFavorite && !p2.isFavorite
                }
                
                switch currentSort {
                case .sortedName:
                    return p1.name < p2.name
                case .sortedDate:
                    return p1.creationDate > p2.creationDate
                }
            }
            
            return filtered
        }
    }
    
    enum Action: BindableAction {
        case onAppear
        case loadProjects(ModelContext)
        case refreshProjects
        case projectTapped(id: Project.ID)
        case favoriteButtonTapped(id: Project.ID, ModelContext)
        case deleteProject(id: Project.ID, ModelContext)
        
        case _projectsResponse(Result<[ProjectPayload], Error>)
        case _favoriteUpdated(id: String, isFavorite: Bool)
        case binding(BindingAction<State>)
        
        case destination(PresentationAction<Destination.Action>)
        
        // 사용자 변경 알림 (AppFeature에서 전달)
        case userChanged(User?)
    }
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                // View에서 context와 함께 loadProjects 호출
                return .none
                
            case .refreshProjects:
                state.refreshTrigger = UUID()
                return .none
                
            case .loadProjects(let context):
                state.isLoading = true
                state.hasLoadedOnce = true
                state.refreshTrigger = nil
                let ownerId = state.currentUser?.ownerId
                
                return .run { [projectLocalDataClient, firebaseClient] send in
                    do {
                        if let ownerId = ownerId {
                            // ✅ 로그인 상태: Firebase 기준
                            print("[ProjectList] 로그인 상태 - Firebase에서 프로젝트 로드: \(ownerId)")
                            
                            // 1. Firebase에서 프로젝트 가져오기
                            let remoteProjects = try await firebaseClient.fetchProjects(ownerId)
                            print("[ProjectList] Firebase에서 \(remoteProjects.count)개 프로젝트 가져옴")
                            
                            // 2. 로컬 SwiftData와 동기화
                            await MainActor.run {
                                do {
                                    // 기존 로컬 데이터 가져오기
                                    let localProjects = try projectLocalDataClient.fetchAll(context, ownerId)
                                    let localIds = Set(localProjects.map { $0.id })
                                    
                                    // Firebase 프로젝트 upsert
                                    for remoteProject in remoteProjects {
                                        if localIds.contains(remoteProject.id) {
                                            // 업데이트
                                            try projectLocalDataClient.update(
                                                context,
                                                remoteProject.id,
                                                remoteProject.name,
                                                remoteProject.isFavorite,
                                                remoteProject.transcript,
                                                .synced
                                            )
                                        } else {
                                            // 새로 추가
                                            try projectLocalDataClient.insert(context, remoteProject)
                                        }
                                    }
                                    
                                    print("[ProjectList] 로컬 SwiftData 동기화 완료")
                                } catch {
                                    print("[ProjectList] 로컬 동기화 실패: \(error)")
                                }
                            }
                            
                            // 3. 최종적으로 로컬에서 읽어서 표시 (동기화 완료된 데이터)
                            let payloads = try await MainActor.run {
                                try projectLocalDataClient.fetchAll(context, ownerId)
                            }
                            await send(._projectsResponse(.success(payloads)))
                            
                        } else {
                            // ✅ 비회원 상태: 로컬만 사용
                            print("[ProjectList] 비회원 상태 - 로컬에서 프로젝트 로드")
                            let payloads = try await MainActor.run {
                                try projectLocalDataClient.fetchAll(context, nil)
                            }
                            await send(._projectsResponse(.success(payloads)))
                        }
                    } catch {
                        await send(._projectsResponse(.failure(error)))
                    }
                }
                
            case .projectTapped(id: let projectId):
                if let project = state.projects[id: projectId] {
                    state.destination = .audioDetail(
                        AudioDetailFeature.State(project: project)
                    )
                }
                return .none
                
            case .favoriteButtonTapped(id: let projectId, let context):
                guard var project = state.projects[id: projectId] else {
                    return .none
                }
                
                let newFavorite = !project.isFavorite
                project.isFavorite = newFavorite
                state.projects[id: projectId] = project
                
                let projectIdString = projectId.uuidString
                let ownerId = state.currentUser?.ownerId
                
                return .run { [projectLocalDataClient, firebaseClient] send in
                    do {
                        // SwiftData 업데이트 - MainActor에서 실행
                        try await MainActor.run {
                            try projectLocalDataClient.update(
                                context,
                                projectIdString,
                                nil,  // name
                                newFavorite,
                                nil,  // transcript
                                nil  // syncStatus
                            )
                        }
                        
                        // 로그인 사용자면 Firebase도 업데이트
                        if let ownerId {
                            let payloads = try await MainActor.run {
                                try projectLocalDataClient.fetchAll(
                                    context,
                                    ownerId
                                )
                            }
                            if let payload = payloads.first(where: {
                                $0.id == projectIdString
                            }) {
                                try await firebaseClient.updateProject(
                                    ownerId,
                                    payload
                                )
                            }
                        }
                        
                        await send(
                            ._favoriteUpdated(
                                id: projectIdString,
                                isFavorite: newFavorite
                            )
                        )
                    } catch {
                        print("즐겨찾기 업데이트 실패: \(error)")
                    }
                }
                
            case .deleteProject(id: let projectId, let context):
                guard let project = state.projects[id: projectId] else {
                    return .none
                }
                let projectIdString = projectId.uuidString
                let ownerId = state.currentUser?.ownerId
                let remotePath = project.filePath
                
                // UI에서 먼저 제거
                state.projects.remove(id: projectId)
                
                return .run { [projectLocalDataClient, firebaseClient, fileCloudClient] _ in
                    do {
                        // SwiftData에서 삭제 - MainActor에서 실행
                        try await MainActor.run {
                            try projectLocalDataClient.delete(
                                context,
                                projectIdString
                            )
                        }
                        
                        if let ownerId {
                            if let remotePath, !remotePath.isEmpty {
                                do {
                                    try await fileCloudClient.deleteFile(remotePath)
                                    print("Storage 오디오 파일 삭제 완료: \(remotePath)")
                                } catch {
                                    print("Storage 오디오 파일 삭제 실패 (계속 진행): \(error.localizedDescription)")
                                }
                            }
                            // 로그인 사용자면 Firebase에서도 삭제
                            try await firebaseClient.deleteProject(
                                ownerId,
                                projectIdString
                            )
                        }
                        print("프로젝트 삭제 완료: \(projectIdString)")
                    } catch {
                        print("프로젝트 삭제 실패: \(error)")
                    }
                }
                
            case ._projectsResponse(.success(let payloads)):
                state.isLoading = false
                
                // ProjectPayload → Project 변환
                let projects = payloads.map { payload -> Project in
                    Project(
                        id: UUID(uuidString: payload.id) ?? UUID(),
                        name: payload.name,
                        creationDate: payload.creationDate,
                        category: payload.category,
                        isFavorite: payload.isFavorite,
                        filePath: payload.filePath,
                        fileLength: payload.fileLength,
                        transcript: payload.transcript,
                        syncStatus: payload.syncStatus ?? .localOnly
                    )
                }
                
                state.projects = IdentifiedArrayOf(uniqueElements: projects)
                return .none
                
            case ._projectsResponse(.failure(let error)):
                state.isLoading = false
                state.refreshTrigger = nil
                print("프로젝트 조회 실패: \(error)")
                return .none
                
            case ._favoriteUpdated:
                // 이미 State에서 업데이트됨
                return .none
                
            case .userChanged(let user):
                state.currentUser = user
                return .send(.refreshProjects)
                
            case .destination, .binding:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination) {
            Destination()
        }
    }
}

// MARK: - Navigation Destination

extension ProjectListFeature {
    @Reducer
    struct Destination {
        @ObservableState
        enum State: Equatable {
            case audioDetail(AudioDetailFeature.State)
        }
        
        enum Action {
            case audioDetail(AudioDetailFeature.Action)
        }
        
        var body: some Reducer<State, Action> {
            Scope(state: \.audioDetail, action: \.audioDetail) {
                AudioDetailFeature()
            }
        }
    }
}
