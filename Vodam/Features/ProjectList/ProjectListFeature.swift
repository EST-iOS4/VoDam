import ComposableArchitecture
import Foundation

@Reducer
struct ProjectListFeature {
    @ObservableState
    struct State: Equatable {
        // 1. 원본 데이터 및 UI 상태
        var projects: IdentifiedArrayOf<Project> = Project.mock
        var isLoading = false
        var allCategories: [Category] =  Category.allCases
        var selectedCategory: Category = .all
        var currentSort: SortFilter = .sortedDate
        var searchText: String = ""

        // 2. 화면 이동 상태 (상세 화면)
        // 자식뷰의 상태를 관리하는 변수로, nil 인 경우, 상세화면이 보이지 않고, nil이 아니라면 상세화면
        @Presents var destination: Destination.State?

        var filteredAndSortedProjects: IdentifiedArrayOf<Project> {
            var filtered = projects
            // 카테고리 필터링
            if selectedCategory != .all {
                filtered = filtered.filter { $0.category == selectedCategory }
            }
            
            if !searchText.isEmpty {
                filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            // 정렬
            switch currentSort {
            case .sortedName:
                filtered.sort { $0.name < $1.name }
            case .sortedDate:
                filtered.sort { $0.creationDate < $1.creationDate }
            }
            return filtered
        }
    }

    enum Action: BindableAction {
        // 사용자 액션
        case onAppear
        case projectTapped(id: Project.ID)

        // 내부 액션
        case _projectsResponse(Result<IdentifiedArrayOf<Project>, Error>)
        case binding(BindingAction<State>)

        // 화면 전환 액션
        case destination(PresentationAction<Destination.Action>)
    }
    
//    @Dependency(\.continuousClock) var clock
    
    // MARK: - Reducer Body
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                // TODO: 실제 파이어베이스에 저장된 데이터를 불러오는 로직으로 교체해야함.
                return .run { send in
//                    try await self.clock.sleep(for: .seconds(1))
                    await send(._projectsResponse(
                        Result { try await Task.sleep(for: .seconds(1))
//                            clock.sleep(for: .seconds(1))
                            return Project.mock
                        }
                    ))
                }

            case let .projectTapped(id: projectId):
                // 탭한 프로젝트의 상세 정보를 Destination으로 설정하여 화면 전환
                if let project = state.projects[id: projectId] {
                    state.destination = .detail(ProjectDetailFeature.State(project: project))
                }
                return .none

            case let ._projectsResponse(.success(projects)):
                state.isLoading = false
                state.projects = projects
                return .none

            case ._projectsResponse(.failure):
                state.isLoading = false
                // TODO: 에러 처리 (예: 에러 알림 표시)
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
            // TODO: 실제 프로젝트 상세 화면의 Feature로 교체
            case detail(ProjectDetailFeature.State)
        }
        
        enum Action {
            case detail(ProjectDetailFeature.Action)
        }
        
        var body: some Reducer<State, Action> {
            Scope(state: \.detail, action: \.detail) {
                ProjectDetailFeature()
            }
        }
    }
}

struct Project: Hashable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var creationDate: Date
    var category: Category
    
    static let mock: IdentifiedArrayOf<Project> = [
        Project(id: UUID(), name: "파일로 저장된 프로젝트", creationDate: Date(), category: .file),
        Project(id: UUID(), name: "PDF로 저장된 프로젝트", creationDate: Date(), category: .pdf),
        Project(id: UUID(), name: "녹음으로 저장된 프로젝트", creationDate: Date().addingTimeInterval(-2000000), category: .recording),
        Project(id: UUID(), name: "녹음으로 저장된 프로젝트2", creationDate: Date().addingTimeInterval(-150000), category: .recording)
    ]
}
