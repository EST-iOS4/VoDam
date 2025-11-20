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
        var isFavorite = false
        
        // 2. 화면 이동 상태 (상세 화면)
        // 자식뷰의 상태를 관리하는 변수로, nil 인 경우, 상세화면이 보이지 않고, nil이 아니라면 상세화면
        @Presents var destination: Destination.State?
        
        var projectState: IdentifiedArrayOf<Project> {
            var filtered = projects
            // 카테고리 필터링
            if selectedCategory != .all {
                filtered = filtered.filter { $0.category == selectedCategory }
            }
            
            if !searchText.isEmpty {
                filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            
            // 정렬
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
        // 사용자 액션
        case onAppear
        case projectTapped(id: Project.ID)
        case favoriteButtonTapped(id: Project.ID)
        
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
                if let project = state.projects[id: projectId] {
                    switch project.category {
                    case .pdf:
                        state.destination = .pdfDetail(PdfDetailFeature.State(project: project))
                    case .file, .recording:
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
            // TODO: 실제 프로젝트 상세 화면의 Feature로 교체
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

struct Project: Hashable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var creationDate: Date
    var category: Category
    var isFavorite: Bool
    
    static let mock: IdentifiedArrayOf<Project> = [
        Project(id: UUID(), name: "파일로 저장된 프로젝트", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 19)) ?? Date(), category: .file, isFavorite: false),
        Project(id: UUID(), name: "PDF로 저장된 프로젝트", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 18)) ?? Date(), category: .pdf, isFavorite: false),
        Project(id: UUID(), name: "저장된 프로젝트1", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 17)) ?? Date(), category: .recording, isFavorite: false),
        Project(id: UUID(), name: "2025저장된 프로젝트", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 4, day: 17)) ?? Date(), category: .recording, isFavorite: false),
        Project(id: UUID(), name: "ㅁㄴㅇㅁㄴㅇ", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 5, day: 17)) ?? Date(), category: .recording, isFavorite: false),
        Project(id: UUID(), name: "121124", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 17)) ?? Date(), category: .recording, isFavorite: false),
        Project(id: UUID(), name: "7", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 16)) ?? Date(), category: .recording, isFavorite: false),
        Project(id: UUID(), name: "8", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 8, day: 16)) ?? Date(), category: .recording, isFavorite: false),
        Project(id: UUID(), name: "9", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 9, day: 16)) ?? Date(), category: .recording, isFavorite: false),
        Project(id: UUID(), name: "10", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 10, day: 16)) ?? Date(), category: .recording, isFavorite: false),
        Project(id: UUID(), name: "11", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 11, day: 16)) ?? Date(), category: .recording, isFavorite: false),
        Project(id: UUID(), name: "12", creationDate: Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 16)) ?? Date(), category: .recording, isFavorite: false)
    ]
}
