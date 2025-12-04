//
// ProjectListFeature.swift
// Vodam
//
// Created by 서정원 on 11/17/25.
//


import ComposableArchitecture
import Foundation

@Reducer
struct ProjectListFeature {
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    @Dependency(\.firebaseClient) var firebaseClient
    @Dependency(\.fileCloudClient) var fileCloudClient
    
    struct AISummaryProgressState: Equatable {
        var progress: Double
        var message: String?
    }
    
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
        
        var currentUser: User? = nil
        
        var aiSummaryProgress: [String: AISummaryProgressState] = [:]
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
                case .sortedName: return p1.name < p2.name
                case .sortedDate: return p1.creationDate > p2.creationDate
                }
            }
            return filtered
        }
    }
    
    enum Action: BindableAction {
        case onAppear
        case loadProjects
        case refreshProjects
        case projectTapped(id: Project.ID)
        case favoriteButtonTapped(id: Project.ID)
        case deleteProject(id: Project.ID)
        
        case _projectsResponse(Result<[ProjectPayload], Error>)
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case userChanged(User?)
        
        case aiSummaryRequested(ProjectId: String, transcript: String, ownerId: String?)
        case aiSummaryResponse(projectId: String, summary: String)
        case aiSummaryFailed(projectId: String)
        case aiSummaryProgressUpdated(projectId: String, progress: Double, message: String?)
    }
    
    nonisolated enum ProjectListCancelID { case loadProjects }
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
                
            case .refreshProjects:
                state.refreshTrigger = UUID()
                return .none
                
            case .loadProjects:
                guard !state.isLoading else { return .none }
                
                state.isLoading = true
                state.hasLoadedOnce = true
                state.refreshTrigger = nil
                let ownerId = state.currentUser?.ownerId
                
                return .run { [projectLocalDataClient, firebaseClient, fileCloudClient] send in
                    do {
                        if let ownerId {
                            let remoteProjects = try await firebaseClient.fetchProjects(ownerId)
                            
                            let localProjects = try await projectLocalDataClient.fetchAll(ownerId)
                            let localIds = Set(localProjects.map { $0.id })
                            let remoteIds = Set(remoteProjects.map { $0.id })
                            
                            for remoteProject in remoteProjects {
                                if localIds.contains(remoteProject.id) {
                                    try await projectLocalDataClient.update(
                                        remoteProject.id, remoteProject.name, remoteProject.isFavorite,
                                        remoteProject.transcript, .synced, remoteProject.summary
                                    )
                                } else {
                                    try await projectLocalDataClient.insert(remoteProject)
                                }
                            }
                            
                            for project in localProjects where !remoteIds.contains(project.id) && project.syncStatus == .synced {
                                try await projectLocalDataClient.delete(project.id)
                            }
                            
                            await Self.cleanupOrphanedStorageFiles(ownerId: ownerId, remoteProjects: remoteProjects, fileCloudClient: fileCloudClient)
                            let payloads = try await projectLocalDataClient.fetchAll(ownerId)
                            await send(._projectsResponse(.success(payloads)))
                        } else {
                            let payloads = try await projectLocalDataClient.fetchAll(nil)
                            await send(._projectsResponse(.success(payloads)))
                        }
                    } catch {
                        await send(._projectsResponse(.failure(error)))
                    }
                }
                .cancellable(id: ProjectListCancelID.loadProjects, cancelInFlight: true)
                
            case .projectTapped(id: let projectId):
                guard let project = state.projects[id: projectId] else { return .none }
                
                let projectIdString = project.id.uuidString
                let hasSummary = !(project.summary ?? "").isEmpty
                let hasInProgress = state.aiSummaryProgress[projectIdString] != nil
                let initialTab: AudioDetailFeature.Tab = (hasSummary || hasInProgress) ? .aiSummary : .script
                
                var detailState = AudioDetailFeature.State(project: project, currentUser: state.currentUser, selectedTab: initialTab)
                if let progressInfo = state.aiSummaryProgress[projectIdString] {
                    detailState.aiSummary.isLoading = true
                    detailState.aiSummary.progress = progressInfo.progress
                    detailState.aiSummary.progressMessage = progressInfo.message
                }
                state.destination = .audioDetail(detailState)
                return .none
                
            case .favoriteButtonTapped(id: let projectId):
                guard var project = state.projects[id: projectId] else { return .none }
                
                let newFavorite = !project.isFavorite
                project.isFavorite = newFavorite
                state.projects[id: projectId] = project
                
                let projectIdString = projectId.uuidString
                let ownerId = state.currentUser?.ownerId
                
                return .run { [projectLocalDataClient, firebaseClient] send in
                    do {
                        try await projectLocalDataClient.update(projectIdString, nil, newFavorite, nil, nil, nil)
                        if let ownerId {
                            let payloads = try await projectLocalDataClient.fetchAll(ownerId)
                            if let payload = payloads.first(where: { $0.id == projectIdString }) {
                                try await firebaseClient.updateProject(ownerId, payload)
                            }
                        }
                    } catch {
                        print("즐겨찾기 업데이트 실패: \(error)")
                    }
                }
                
            case .deleteProject(id: let projectId):
                guard let project = state.projects[id: projectId] else { return .none }
                let projectIdString = projectId.uuidString
                let ownerId = state.currentUser?.ownerId
                let remotePath = project.remoteAudioPath ?? project.filePath
                
                state.projects.remove(id: projectId)
                
                return .run { [projectLocalDataClient, firebaseClient, fileCloudClient] _ in
                    do {
                        try await projectLocalDataClient.delete(projectIdString)
                        if let ownerId {
                            if let remotePath, !remotePath.isEmpty {
                                try? await fileCloudClient.deleteFile(remotePath)
                            }
                            try await firebaseClient.deleteProject(ownerId, projectIdString)
                            try? await firebaseClient.deleteChatRoom(ownerId, projectIdString)
                        }
                    } catch {
                        print("프로젝트 삭제 실패: \(error)")
                    }
                }
                
            case ._projectsResponse(.success(let payloads)):
                state.isLoading = false
                state.projects = IdentifiedArrayOf(uniqueElements: payloads.map { payload in
                    Project(
                        id: UUID(uuidString: payload.id) ?? UUID(),
                        name: payload.name, creationDate: payload.creationDate, category: payload.category,
                        isFavorite: payload.isFavorite, filePath: payload.filePath, fileLength: payload.fileLength,
                        transcript: payload.transcript, syncStatus: payload.syncStatus, summary: payload.summary,
                        remoteAudioPath: payload.remoteAudioPath
                    )
                })
                return .none
                
            case let .aiSummaryProgressUpdated(projectId, progress, message):
                state.aiSummaryProgress[projectId] = AISummaryProgressState(progress: progress, message: message)
                return .none
                
            case ._projectsResponse(.failure(let error)):
                state.isLoading = false
                state.refreshTrigger = nil
                print("프로젝트 조회 실패: \(error)")
                return .none
                
            case .userChanged(let user):
                state.currentUser = user
                state.destination = nil
                return .send(.refreshProjects)
                
            case .destination(.presented(.audioDetail(.delegate(.didDeleteProject)))):
                state.destination = nil
                return .none
                
            case .destination(.presented(.audioDetail(.delegate(.needsRefresh)))):
                return .send(.refreshProjects)
                
            case .destination(.presented(.audioDetail(.aiSummary(.summarizeButtonTapped)))):
                guard let destination = state.destination,
                      case let .audioDetail(detailState) = destination
                else { return .none }
                
                return .send(.aiSummaryRequested(
                    ProjectId: detailState.aiSummary.projectId,
                    transcript: detailState.aiSummary.transcript,
                    ownerId: detailState.aiSummary.ownerId
                ))
                
            case let .aiSummaryRequested(projectId, transcript, ownerId):
                return .run { [projectLocalDataClient, firebaseClient] send in
                    do {
                        func updateProgress(_ value: Double, _ message: String) async {
                            await send(.destination(.presented(.audioDetail(.aiSummary(.updateProgress(value, message))))))
                            await send(.aiSummaryProgressUpdated(projectId: projectId, progress: value, message: message))
                        }
                        
                        let chunks = splitTranscript(transcript, maxChunkLength: 800)
                        guard !chunks.isEmpty else {
                            await send(.aiSummaryFailed(projectId: projectId))
                            return
                        }
                        
                        await updateProgress(0.05, "1단계 요약 시작...")
                        
                        // 1단계: 청크별 요약
                        var partialSummaries: [String] = []
                        let batchSize = 8
                        let totalBatches = (chunks.count + batchSize - 1) / batchSize
                        
                        for batchIndex in 0..<totalBatches {
                            let startIdx = batchIndex * batchSize
                            let endIdx = min(startIdx + batchSize, chunks.count)
                            let batchChunks = Array(chunks[startIdx..<endIdx])
                            
                            let batchSummaries: [String] = await withTaskGroup(of: (Int, String?).self) { group in
                                for (localIndex, chunk) in batchChunks.enumerated() {
                                    let globalIndex = startIdx + localIndex
                                    group.addTask {
                                        let q = AlanClient.Question("다음을 1-2문장으로 핵심만 요약:\n\n\(chunk)")
                                        for attempt in 1...2 {
                                            do {
                                                let answer = try await AlanClient.shared.question(q)
                                                return (globalIndex, answer.content)
                                            } catch {
                                                if attempt < 2 { try? await Task.sleep(nanoseconds: 1_000_000_000) }
                                            }
                                        }
                                        return (globalIndex, nil)
                                    }
                                }
                                var results: [(Int, String)] = []
                                for await (index, text) in group {
                                    if let text { results.append((index, text)) }
                                }
                                return results.sorted { $0.0 < $1.0 }.map { $0.1 }
                            }
                            
                            partialSummaries.append(contentsOf: batchSummaries)
                            await updateProgress(0.05 + (Double(endIdx) / Double(chunks.count)) * 0.4, "1단계... \(endIdx)/\(chunks.count)")
                            if batchIndex < totalBatches - 1 { try? await Task.sleep(nanoseconds: 500_000_000) }
                        }
                        
                        // 2단계: 중간 요약
                        let summaryGroups = stride(from: 0, to: partialSummaries.count, by: 5).map {
                            Array(partialSummaries[$0..<min($0 + 5, partialSummaries.count)])
                        }
                        await updateProgress(0.5, "2단계 통합 중...")
                        
                        var intermediateSummaries: [String] = []
                        for (groupIndex, group) in summaryGroups.enumerated() {
                            let combinedGroup = group.joined(separator: " ")
                            let limitedGroup = combinedGroup.count > 800 ? String(combinedGroup.prefix(800)) : combinedGroup
                            let q = AlanClient.Question("다음 요약들을 2-3문장으로 통합:\n\n\(limitedGroup)")
                            
                            for attempt in 1...2 {
                                do {
                                    let answer = try await AlanClient.shared.question(q)
                                    intermediateSummaries.append(answer.content)
                                    break
                                } catch {
                                    if attempt < 2 { try? await Task.sleep(nanoseconds: 1_000_000_000) }
                                }
                            }
                            await updateProgress(0.5 + (Double(groupIndex + 1) / Double(summaryGroups.count)) * 0.3, "2단계... \(groupIndex + 1)/\(summaryGroups.count)")
                            try? await Task.sleep(nanoseconds: 500_000_000)
                        }
                        
                        // 최종 요약
                        await updateProgress(0.85, "최종 요약 생성 중...")
                        let finalInput = intermediateSummaries.joined(separator: " ")
                        let truncatedInput = finalInput.count > 800 ? String(finalInput.prefix(800)) : finalInput
                        let finalQuestion = AlanClient.Question("다음을 3줄로 핵심 정리:\n\n\(truncatedInput)")
                        
                        var finalSummary: String?
                        for attempt in 1...3 {
                            do {
                                let finalAnswer = try await AlanClient.shared.question(finalQuestion)
                                finalSummary = finalAnswer.content
                                break
                            } catch {
                                if attempt < 3 { try? await Task.sleep(nanoseconds: 2_000_000_000) }
                            }
                        }
                        
                        guard let summary = finalSummary else {
                            await send(.aiSummaryFailed(projectId: projectId))
                            return
                        }
                        
                        await updateProgress(0.95, "저장 중...")
                        await send(.aiSummaryResponse(projectId: projectId, summary: summary))
                        
                        // Firebase 저장
                        if let ownerId {
                            let allProjects = try await projectLocalDataClient.fetchAll(ownerId)
                            guard let existingProject = allProjects.first(where: { $0.id == projectId }) else { return }
                            
                            let updatedProject = ProjectPayload(
                                id: existingProject.id, name: existingProject.name, creationDate: existingProject.creationDate,
                                category: existingProject.category, isFavorite: existingProject.isFavorite, filePath: existingProject.filePath,
                                fileLength: existingProject.fileLength, transcript: existingProject.transcript, summary: summary,
                                ownerId: ownerId, syncStatus: existingProject.syncStatus, remoteAudioPath: existingProject.remoteAudioPath
                            )
                            
                            try await firebaseClient.updateProject(ownerId, updatedProject)
                            try await projectLocalDataClient.update(projectId, nil, nil, nil, nil, summary)
                            
                            let preview = (summary.replacingOccurrences(of: "\n", with: "").prefix(25)) + "의 방"
                            try? await firebaseClient.updateChatRoomPreview(ownerId, existingProject.id, existingProject.name, String(preview))
                        }
                        await updateProgress(1.0, "완료!")
                        
                    } catch {
                        await send(.aiSummaryProgressUpdated(projectId: projectId, progress: 0, message: "요약 실패"))
                        await send(.aiSummaryFailed(projectId: projectId))
                    }
                }
                
            case let .aiSummaryResponse(projectId, summary):
                state.aiSummaryProgress[projectId] = nil
                if var destination = state.destination, case var .audioDetail(detail) = destination, detail.aiSummary.projectId == projectId {
                    detail.aiSummary.summary = summary
                    detail.aiSummary.isLoading = false
                    state.destination = .audioDetail(detail)
                }
                if let index = state.projects.firstIndex(where: { $0.id.uuidString == projectId }) {
                    state.projects[index].summary = summary
                }
                return .none
                
            case let .aiSummaryFailed(projectId):
                state.aiSummaryProgress[projectId] = nil
                if var destination = state.destination, case var .audioDetail(detail) = destination, detail.aiSummary.projectId == projectId {
                    detail.aiSummary.isLoading = false
                    detail.aiSummary.summary = "요약 생성에 실패했습니다."
                    state.destination = .audioDetail(detail)
                }
                return .none
                
            case .destination(.presented(.audioDetail)), .destination, .binding:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination) { Destination() }
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
            Scope(state: \.audioDetail, action: \.audioDetail) { AudioDetailFeature() }
        }
    }
}

// MARK: - Helpers
extension ProjectListFeature {
    static func cleanupOrphanedStorageFiles(ownerId: String, remoteProjects: [ProjectPayload], fileCloudClient: FileCloudClient) async {
        do {
            let validRemotePaths = Set(remoteProjects.compactMap { $0.remoteAudioPath })
            let storagePath = "users/\(ownerId)/audio"
            let storageFiles = try await fileCloudClient.listFiles(storagePath)
            let orphanedFiles = storageFiles.filter { !validRemotePaths.contains($0) }
            
            for orphanedPath in orphanedFiles {
                try? await fileCloudClient.deleteFile(orphanedPath)
            }
        } catch {
            print("[ProjectList] Storage 고아 파일 정리 실패: \(error)")
        }
    }
}

fileprivate func splitTranscript(_ text: String, maxChunkLength: Int) -> [String] {
    guard !text.isEmpty else { return [] }
    var result: [String] = []
    var startIndex = text.startIndex
    while startIndex < text.endIndex {
        let endIndex = text.index(startIndex, offsetBy: maxChunkLength, limitedBy: text.endIndex) ?? text.endIndex
        result.append(String(text[startIndex..<endIndex]))
        startIndex = endIndex
    }
    return result
}
