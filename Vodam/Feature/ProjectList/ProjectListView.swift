//
// ProjectListView.swift
// Vodam
//
// Created by 서정원 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI
import SwiftData // <-- 이 줄을 추가하여 FetchDescriptor, ProjectModel 접근 가능하게 함

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var store: StoreOf<ProjectListFeature>
    
    var body: some View {
        NavigationStack {
            VStack {
                categoryPicker
                
                if store.isLoading {
                    loadingView
                } else if store.projectState.isEmpty {
                    emptyView
                } else {
                    projectsList
                }
            }
            .navigationTitle("저장된 프로젝트")
            .searchable(text: $store.searchText, prompt: "프로젝트를 검색하세요.")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    sortMenu
                }
            }
            .onAppear {
                store.send(.loadProjects(modelContext))
            }
            .onChange(of: store.refreshTrigger) { oldValue, newValue in
                if newValue != nil {
                    print("Refresh triggeren: \(newValue?.uuidString ?? "nil")")
                    store.send(.loadProjects(modelContext))
                }
            }
            .navigationDestination(
                store: self.store.scope(state: \.$destination, action: \.destination)
            ) { store in
                destinationView(for: store)
            }
        }
    }
    
    private var categoryPicker: some View {
        Picker(
            "카테고리를 선택하세요.",
            selection: $store.selectedCategory.animation()
        ) {
            ForEach(store.allCategories, id: \.self) { category in
                Text(category.title)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    private var loadingView: some View {
        ProgressView()
            .frame(maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        Text("저장된 프로젝트가 없습니다.")
            .foregroundColor(.secondary)
            .frame(maxHeight: .infinity)
    }
    
    private var projectsList: some View {
        List(store.projectState) { project in
            ProjectRow(
                project: project,
                onTap: { store.send(.projectTapped(id: project.id)) },
                onFavoriteTap: { store.send(.favoriteButtonTapped(id: project.id, modelContext)) }
            )
        }
        .listStyle(.plain)
        .animation(.default, value: store.projectState)
    }
    
    private var sortMenu: some View {
        Menu {
            Picker(
                "정렬 방식을 선택하세요. ",
                selection: $store.currentSort.animation()
            ) {
                ForEach(SortFilter.allCases, id: \.self) { sort in
                    Text(sort.title)
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
    
    // 이 함수는 디버깅 목적으로, 실제 앱에서는 제거하거나 주석 처리하는 것이 좋습니다.
    private func debugPrintAllProjects() {
        print(String(repeating: "=", count: 60))
        print("SwiftData 전체 데이터베이스 조회")
        print(String(repeating: "=", count: 60))
        
        // ProjectModel이 정의되어 있다고 가정하고 FetchDescriptor를 사용합니다.
        // SwiftData를 import 했기 때문에 이제 ProjectModel의 key path를 찾을 수 있습니다.
        let allDescriptor = FetchDescriptor<ProjectModel>(
            sortBy: [SortDescriptor(\.creationDate, order: .reverse)]
        )
        
        do {
            let allModels = try modelContext.fetch(allDescriptor)
            print("전체 프로젝트 수: \(allModels.count)개")
            
            for (index, model) in allModels.enumerated() {
                print("[\(index)] id: \(model.id)")
                print("     name: \(model.name)")
                print("     ownerId: \(model.ownerId ?? "nil")")
                print("     syncStatus: \(model.syncStatusRaw)")
                print("     category: \(model.categoryRaw)")
                print("     creationDate: \(model.creationDate)")
                print("     ---")
            }
        } catch {
            print("전체 조회 실패: \(error)")
        }
        
        print(String(repeating: "=", count: 60))
    }
    
    @ViewBuilder
    private func destinationView(for store: Store<ProjectListFeature.Destination.State, ProjectListFeature.Destination.Action>) -> some View {
        switch store.state {
        case .audioDetail:
            if let detailStore = store.scope(state: \.audioDetail, action: \.audioDetail) {
                AudioDetailView(store: detailStore)
            }
        }
    }
}

struct ProjectRow: View {
    let project: Project
    let onTap: () -> Void
    let onFavoriteTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                categoryIcon
                projectInfo
                Spacer()
                favoriteButton
            }
        }
    }
    
    private var categoryIcon: some View {
        HStack(spacing: 4) {
            categoryImage
            syncStatusIcon
        }
        .frame(width: 30)
    }
    
    @ViewBuilder
    private var categoryImage: some View {
        switch project.category {
        case .audio:
            Image(systemName: "record.circle")
        case .file:
            Image(systemName: "folder")
        case .pdf:
            Image(systemName: "text.rectangle.page")
        @unknown default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var syncStatusIcon: some View {
        if project.syncStatus == .synced {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                )
        } else if project.syncStatus == .localOnly {
            Image(systemName: "iphone")
                .font(.caption2)
                .foregroundColor(.gray)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                )
        }
    }
    
    // MARK: - Project Info
    private var projectInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(.headline)
            
            HStack(spacing: 4) {
                Text(project.creationDate, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                syncStatusText
            }
        }
    }
    
    @ViewBuilder
    private var syncStatusText: some View {
        if project.syncStatus == .synced {
            Text("동기화됨")
                .font(.caption)
                .foregroundColor(.green)
        } else if project.syncStatus == .localOnly {
            Text("로컬만")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Favorite Button
    private var favoriteButton: some View {
        Button(action: onFavoriteTap) {
            Image(systemName: project.isFavorite ? "star.fill" : "star")
                .foregroundColor(.yellow)
        }
        .buttonStyle(.plain)
    }
}
