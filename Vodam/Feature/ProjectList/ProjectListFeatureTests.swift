//
//  ProjectListFeatureTests.swift
//  VodamTests
//
//  Created by 이건준 on 11/25/25.
//

import Testing
import ComposableArchitecture
@testable import Vodam
internal import Foundation

@MainActor
struct ProjectListFeatureTests {
    
    // MARK: - onAppear → 로딩 시작 + 프로젝트 로드 성공
    
    @Test
    func onAppear시_로딩을_시작하고_프로젝트를_성공적으로_로딩한다() async {
        let store = TestStore(
            initialState: ProjectListFeature.State(),
            reducer: { ProjectListFeature() }
        )
        
        await store.send(.onAppear) {
            $0.isLoading = true
        }
        
        await store.receive(\._projectsResponse) {
            $0.isLoading = false
            $0.projects = Project.mock
        }
    }
    
    // MARK: - projectTapped → destination 설정 (오디오/파일/문서)
    
    @Test
    func 프로젝트_선택시_카테고리에_따라_상세화면_destination이_설정된다() async {
        let initialState = ProjectListFeature.State(
            projects: Project.mock
        )
        
        let store = TestStore(
            initialState: initialState,
            reducer: { ProjectListFeature() }
        )
        
        guard let first = store.state.projects.first else {
            Issue.record("Project.mock에 최소 한 개 이상의 프로젝트가 필요합니다.")
            return
        }
        
        let expectedDestination: ProjectListFeature.Destination.State
        switch first.category {
        case .pdf:
            expectedDestination = .pdfDetail(
                PdfDetailFeature.State(project: first)
            )
        case .file, .audio:
            expectedDestination = .audioDetail(
                AudioDetailFeature.State(project: first)
            )
        @unknown default:
            Issue.record("지원하지 않는 카테고리입니다.")
            return
        }
        
        await store.send(.projectTapped(id: first.id)) {
            $0.destination = expectedDestination
        }
    }
    
    // MARK: - favorite 버튼 토글
    
    @Test
    func 즐겨찾기_버튼_탭시_해당_프로젝트의_isFavorite이_토글된다() async {
        let initialState = ProjectListFeature.State(
            projects: Project.mock
        )
        
        let store = TestStore(
            initialState: initialState,
            reducer: { ProjectListFeature() }
        )
        
        guard let first = store.state.projects.first else {
            Issue.record("Project.mock에 최소 한 개 이상의 프로젝트가 필요합니다.")
            return
        }
        
        let originalFavorite = first.isFavorite
        
        await store.send(.favoriteButtonTapped(id: first.id)) {
            $0.projects[id: first.id]?.isFavorite = !originalFavorite
        }
    }
    
    // MARK: - 카테고리 필터 & 검색 바인딩 (간단 예시)
    
    @Test
    func 카테고리와_검색어_변경시_projectState가_필터링된다() async {
        var mock = Project.mock
        
        let store = TestStore(
            initialState: ProjectListFeature.State(
                projects: mock,
                allCategories: Category.allCases,
                selectedCategory: .all,
                currentSort: .sortedDate,
                searchText: ""
            ),
            reducer: { ProjectListFeature() }
        )
        
        if let someCategory = Category.allCases.first(where: { $0 != .all }) {
            await store.send(.binding(.set(\.selectedCategory, someCategory))) {
                $0.selectedCategory = someCategory
            }
            
            let filtered = store.state.projectState
            #expect(filtered.allSatisfy { $0.category == someCategory })
        }
        
        await store.send(.binding(.set(\.searchText, "테스트"))) {
            $0.searchText = "테스트"
        }
        
        let searchFiltered = store.state.projectState
        if !searchFiltered.isEmpty {
            #expect(
                searchFiltered.allSatisfy {
                    $0.name.localizedCaseInsensitiveContains("테스트")
                }
            )
        }
    }
}

