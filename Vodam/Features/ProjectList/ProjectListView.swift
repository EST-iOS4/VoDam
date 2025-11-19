//
//  ProjectListView.swift
//  Vodam
//
//  Created by 서정원 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct ProjectListView: View {
    @Bindable var store: StoreOf<ProjectListFeature>
    
    var body: some View {
        NavigationStack {
            VStack {
                // MARK: - Category Segmented Control
                Picker(
                    "",
                    selection: $store.selectedCategory.animation()
                ) {
                    ForEach(store.allCategories, id: \.self) { category in
                        Text(category.title)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // MARK: - Content View
                if store.isLoading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else if store.projectState.isEmpty {
                    Text("저장된 프로젝트가 없습니다.")
                        .foregroundColor(.secondary)
                        .frame(maxHeight: .infinity)
                } else {
                    // MARK: - Projects List
                    List(store.projectState) { project in
                        Button(action: { store.send(.projectTapped(id: project.id)) }) {
                            HStack {
                                switch project.category {
                                case .recording:
                                    Image(systemName: "record.circle")
                                case .file:
                                    Image(systemName: "folder")
                                case .pdf:
                                    Image(systemName: "text.rectangle.page")
                                @unknown default:
                                    EmptyView()
                                }
                                VStack(alignment: .leading) {
                                    Text(project.name)
                                        .font(.headline)
                                    Text(project.creationDate, style: .date)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    store.send(.favoriteButtonTapped(id: project.id))
                                }) {
                                    Image(systemName: project.isFavorite ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .animation(.default, value: store.projectState)
                }
            }
            .navigationTitle("저장된 프로젝트")
            .searchable(text: $store.searchText, prompt: "프로젝트를 검색하세요.")
            .toolbar {
                // MARK: - Sort Filter Menu
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker(
                            "정렬 방식",
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
            .onAppear {
                store.send(.onAppear)
            }
            // MARK: - Navigation to Detail View
            .navigationDestination(
                store: store.scope(state: \.$destination, action: \.destination),
                state: /ProjectListFeature.Destination.State.detail,
                action: ProjectListFeature.Destination.Action.detail
            ) { store in
                ProjectDetailView(store: store)
            }
        }
    }
}

#Preview {
    ProjectListView(
        store: Store(
            initialState: ProjectListFeature.State(
                projects: Project.mock
            )
        ) {
            ProjectListFeature()
        }
    )
}
