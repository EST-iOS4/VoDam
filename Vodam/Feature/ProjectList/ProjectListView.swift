//
// ProjectListView.swift
// Vodam
//
// Created by 서정원 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI
import SwiftData

struct ProjectListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var store: StoreOf<ProjectListFeature>
    
    var body: some View {
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
            .task {
                if !store.hasLoadedOnce {
                    print("[ProjectListView] 최초 로드 시작")
                    store.send(.loadProjects(modelContext))
                }
            }
            .onChange(of: store.refreshTrigger) { oldValue, newValue in
                if newValue != nil && oldValue != newValue {
                    print("[ProjectListView] Refresh triggered: \(newValue?.uuidString ?? "nil")")
                    store.send(.loadProjects(modelContext))
                }
            }
            // ✅ navigationDestination을 item 기반으로 변경
            .navigationDestination(
                item: $store.scope(state: \.destination?.audioDetail, action: \.destination.audioDetail)
            ) { detailStore in
                AudioDetailView(store: detailStore)
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
        VStack(spacing: 16) {
            Text("저장된 프로젝트가 없습니다.")
                .font(AppFont.pretendardBold(size: 16))
                .foregroundColor(.secondary)
            
            if store.currentUser != nil {
                Text("아래로 당겨서 동기화할 수 있습니다.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var projectsList: some View {
        List(store.projectState) { project in
            ProjectRow(
                project: project,
                onTap: { store.send(.projectTapped(id: project.id)) },
                onFavoriteTap: { store.send(.favoriteButtonTapped(id: project.id, modelContext)) }
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    store.send(.deleteProject(id: project.id, modelContext))
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: store.projectState)
        .refreshable {
            print("[ProjectListView] Pull-to-refresh 트리거")
            await withCheckedContinuation { continuation in
                store.send(.loadProjects(modelContext))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    continuation.resume()
                }
            }
        }
    }
    
    private var sortMenu: some View {
        Menu {
            Picker(
                "정렬 방식을 선택하세요.",
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
}

// MARK: - ProjectRow

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
    
    private var favoriteButton: some View {
        Button(action: onFavoriteTap) {
            Image(systemName: project.isFavorite ? "star.fill" : "star")
                .foregroundColor(.yellow)
        }
        .buttonStyle(.plain)
    }
}
