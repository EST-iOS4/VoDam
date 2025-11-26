import ComposableArchitecture
import Foundation

@Reducer
struct ProjectListFeature {
    @ObservableState
    struct State: Equatable {
        var projects: IdentifiedArrayOf<Project> = Project.mock
        var isLoading = false
        var allCategories: [FilterCategory] =  FilterCategory.allCases
        var selectedCategory: FilterCategory = .all
        var currentSort: SortFilter = .sortedDate
        var searchText: String = ""
        var isFavorite = false
        
        @Presents var destination: Destination.State?
        
        var projectState: IdentifiedArrayOf<Project> {
            var filtered = projects
            
            if let selectedProjectCategory = selectedCategory.projectCategory {
                filtered = filtered.filter { $0.category == selectedProjectCategory }
            }
            
            if !searchText.isEmpty {
                filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            
            filtered.sort { p1, p2 in
                if p1.isFavorite != p2.isFavorite {
                    return p1.isFavorite && !p2.isFavorite
                }
                
                switch currentSort {
                case .sortedName:
                    return p1.name < p2.name
                case .sortedDate:
                    return p1.creationDate < p2.creationDate
                }
            }
            
            return filtered
        }
    }
    
    enum Action: BindableAction {
        case onAppear
        case projectTapped(id: Project.ID)
        case favoriteButtonTapped(id: Project.ID)
        
        case _projectsResponse(Result<IdentifiedArrayOf<Project>, Error>)
        case binding(BindingAction<State>)
        
        case destination(PresentationAction<Destination.Action>)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                // TODO: 실제 파이어베이스에 저장된 데이터를 불러오는 로직으로 교체해야함.
                return .run { send in

                    await send(._projectsResponse(
                        Result { try await Task.sleep(for: .seconds(1))
                            return Project.mock
                        }
                    ))
                }
                
            case let .projectTapped(id: projectId):
                if let project = state.projects[id: projectId] {
                    switch project.category {
                    case .pdf:
                        state.destination = .pdfDetail(PdfDetailFeature.State(project: project))
                    case .file, .audio:
                        state.destination = .audioDetail(AudioDetailFeature.State(project: project))
                    @unknown default:
                        return .none
                    }
                }
                return .none
                
            case let .favoriteButtonTapped(id: projectId):
                //TODO: 파이어베이스에 저장된 상태도 변경이 되어야해서 .run 으로 변경해야 한다.
                if var project = state.projects[id: projectId] {
                    project.isFavorite.toggle()
                    state.projects[id: projectId] = project
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
            case audioDetail(AudioDetailFeature.State)
            case pdfDetail(PdfDetailFeature.State)
        }
        
        enum Action {
            case audioDetail(AudioDetailFeature.Action)
            case pdfDetail(PdfDetailFeature.Action)
        }
        
        var body: some Reducer<State, Action> {
            Scope(state: \.audioDetail, action: \.audioDetail) {
                AudioDetailFeature()
            }
            Scope(state: \.pdfDetail, action: \.pdfDetail) {
                PdfDetailFeature()
            }
        }
    }
}
