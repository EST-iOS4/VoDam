import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct ProjectListFeature {
    
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient
    @Dependency(\.audioCloudClient) var audioCloudClient
    
    @ObservableState
    struct State: Equatable {
        var projects: IdentifiedArrayOf<Project> = []
        var isLoading = false
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
                
            case .loadProjects(let context):
                state.isLoading = true
                let ownerId = state.currentUser?.ownerId
                
                return .run { [projectLocalDataClient] send in
                    do {
                        let payloads = try projectLocalDataClient.fetchAll(
                            context,
                            ownerId
                        )
                        await send(._projectsResponse(.success(payloads)))
                    } catch {
                        await send(._projectsResponse(.failure(error)))
                    }
                }
                
            case .projectTapped(id: let projectId):
                if let project = state.projects[id: projectId] {
//                    switch project.category {
//                    case .pdf:
//                        state.destination = .pdfDetail(
//                            PdfDetailFeature.State(project: project)
//                        )
//                    case .file, .audio:
                        state.destination = .audioDetail(
                            AudioDetailFeature.State(project: project)
                        )
//                    }
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
                        // SwiftData 업데이트
                        try projectLocalDataClient.update(
                            context,
                            projectIdString,
                            nil,  // name
                            newFavorite,
                            nil,  // transcript
                            nil  // syncStatus
                        )
                        
                        // 로그인 사용자면 Firebase도 업데이트
                        if let ownerId {
                            let payloads = try projectLocalDataClient.fetchAll(
                                context,
                                ownerId
                            )
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
                        print("❌ 즐겨찾기 업데이트 실패: \(error)")
                    }
                }
                
            case .deleteProject(id: let projectId, let context):
                let projectIdString = projectId.uuidString
                let ownerId = state.currentUser?.ownerId
                
                // UI에서 먼저 제거
                state.projects.remove(id: projectId)
                
                return .run { [projectLocalDataClient, firebaseClient, audioCloudClient] _ in
                    do {
                        // SwiftData에서 삭제
                        try projectLocalDataClient.delete(
                            context,
                            projectIdString
                        )
                        
                        if let ownerId {
                            do {
                                try await audioCloudClient.deleteAudio(
                                    ownerId,
                                    projectIdString
                                )
                                print(
                                    "Storage 오디오 파일 삭제 완료: \(projectIdString)"
                                )
                            } catch {
                                print(
                                    "Storage 오디오 파일 삭제 실패 (계속 진행): \(error.localizedDescription)"
                                )
                                
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
                print("프로젝트 조회 실패: \(error)")
                return .none
                
            case ._favoriteUpdated:
                // 이미 State에서 업데이트됨
                return .none
                
            case .userChanged(let user):
                state.currentUser = user
                return .none

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
//            case pdfDetail(PdfDetailFeature.State)
        }

        enum Action {
            case audioDetail(AudioDetailFeature.Action)
//            case pdfDetail(PdfDetailFeature.Action)
        }

        var body: some Reducer<State, Action> {
            Scope(state: \.audioDetail, action: \.audioDetail) {
                AudioDetailFeature()
            }
//            Scope(state: \.pdfDetail, action: \.pdfDetail) {
//                PdfDetailFeature()
//            }
        }
    }
}
