//
// ProjectListFeature.swift
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
        case binding(BindingAction<State>)
        
        case destination(PresentationAction<Destination.Action>)
        
        case userChanged(User?)
        
        case aiSummaryRequested(
            ProjectId: String,
            transcript: String,
            ownerId: String?,
            context: ModelContext
        )
        case aiSummaryResponse(projectId: String, summary: String)
        case aiSummaryFailed(projectId: String)
    }
    
    nonisolated enum ProjectListCancelID{ case loadProjects }
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
                
            case .refreshProjects:
                state.refreshTrigger = UUID()
                return .none
                
            case .loadProjects(let context):
                
                guard !state.isLoading else {
                    print("[ProjectList] 이미 로딩 중 - 중복 호출 무시")
                    return .none
                }
                
                state.isLoading = true
                state.hasLoadedOnce = true
                state.refreshTrigger = nil
                let ownerId = state.currentUser?.ownerId
                
                return .run { [projectLocalDataClient, firebaseClient, fileCloudClient] send in
                    do {
                        if let ownerId = ownerId {
                            print("[ProjectList] 로그인 상태 - Firebase에서 프로젝트 로드: \(ownerId)")
                            
                            let remoteProjects = try await firebaseClient.fetchProjects(ownerId)
                            print("[ProjectList] 🔥 Firebase에서 \(remoteProjects.count)개 프로젝트 가져옴:")
                            for (index, project) in remoteProjects.enumerated() {
                                print("  [\(index)] id: \(project.id), name: \(project.name)")
                            }
                            
                            await MainActor.run {
                                do {
                                    let localProjects = try projectLocalDataClient.fetchAll(context, ownerId)
                                    let localIds = Set(localProjects.map { $0.id })
                                    let remoteIds = Set(remoteProjects.map { $0.id })
                                    
                                    print("[ProjectList] 🔍 동기화 시작:")
                                    print("  - 로컬 프로젝트: \(localProjects.count)개")
                                    print("  - Firebase 프로젝트: \(remoteProjects.count)개")
                                    print("  - 로컬 IDs: \(localIds)")
                                    print("  - Firebase IDs: \(remoteIds)")
                                    
                                    for remoteProject in remoteProjects {
                                        if localIds.contains(remoteProject.id) {
                                            print("[ProjectList] ✏️ 업데이트: \(remoteProject.name)")
                                            try projectLocalDataClient.update(
                                                context,
                                                remoteProject.id,
                                                remoteProject.name,
                                                remoteProject.isFavorite,
                                                remoteProject.transcript,
                                                .synced,
                                                remoteProject.summary
                                            )
                                        } else {
                                            print("[ProjectList] ➕ 추가: \(remoteProject.name)")
                                            try projectLocalDataClient.insert(context, remoteProject)
                                        }
                                    }
                                    
                                    let projectsToDelete = localProjects.filter { localProject in
                                        let shouldDelete = !remoteIds.contains(localProject.id) && localProject.syncStatus == .synced
                                        if shouldDelete {
                                            print("[ProjectList] 🗑️ 삭제 대상 발견: \(localProject.name) (id: \(localProject.id), syncStatus: \(localProject.syncStatus.rawValue))")
                                        }
                                        return shouldDelete
                                    }
                                    
                                    for project in projectsToDelete {
                                        print("[ProjectList] 🗑️ Firebase에 없는 로컬 프로젝트 삭제 실행: \(project.name)")
                                        try projectLocalDataClient.delete(context, project.id)
                                    }
                                    
                                    print("[ProjectList] ✅ 로컬 SwiftData 양방향 동기화 완료 - 추가/업데이트: \(remoteProjects.count)개, 삭제: \(projectsToDelete.count)개")
                                } catch {
                                    print("[ProjectList] ❌ 로컬 동기화 실패: \(error)")
                                }
                            }
                            
                            await Self.cleanupOrphanedStorageFiles(
                                ownerId: ownerId,
                                remoteProjects: remoteProjects,
                                fileCloudClient: fileCloudClient
                            )
                            
                            let payloads = try await MainActor.run {
                                try projectLocalDataClient.fetchAll(context, ownerId)
                            }
                            await send(._projectsResponse(.success(payloads)))
                            
                        } else {
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
                .cancellable(id: ProjectListCancelID.loadProjects, cancelInFlight: true)
                
            case .projectTapped(id: let projectId):
                guard let project = state.projects[id: projectId] else {
                    return .none
                }
                
                let hasSummary = !(project.summary ?? "").isEmpty
                
                let initialTab: AudioDetailFeature.Tab = hasSummary ? .aiSummary : .script
                
                state.destination = .audioDetail(
                    AudioDetailFeature.State(
                        project: project,
                        currentUser: state.currentUser,
                        selectedTab: initialTab
                    )
                )
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
                        try await MainActor.run {
                            try projectLocalDataClient.update(
                                context,
                                projectIdString,
                                nil,
                                newFavorite,
                                nil,
                                nil,
                                nil
                            )
                        }
                        
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
                let remotePath = project.remoteAudioPath ?? project.filePath
                
                state.projects.remove(id: projectId)
                
                return .run { [projectLocalDataClient, firebaseClient, fileCloudClient] _ in
                    do {
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
                        syncStatus: payload.syncStatus,
                        summary: payload.summary,
                        remoteAudioPath: payload.remoteAudioPath
                    )
                }
                
                state.projects = IdentifiedArrayOf(uniqueElements: projects)
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
                
            case let .destination(.presented(.audioDetail(.aiSummary(.summarizeButtonTapped(context))))):
                guard let destination = state.destination,
                      case let .audioDetail(detailState) = destination
                else { return .none }
                
                let transcript = detailState.aiSummary.transcript
                let projectId = detailState.aiSummary.projectId
                let ownerId = detailState.aiSummary.ownerId
                
                return .send(
                    .aiSummaryRequested(ProjectId: projectId, transcript: transcript, ownerId: ownerId, context: context)
                )
                
            case let .aiSummaryRequested(projectId, transcript, ownerId, context):
                return .run { [projectLocalDataClient, firebaseClient, context, ownerId] send in
                    do {
                        let chunks = await splitTranscript(transcript, maxChunkLength: 1300)
                        
                        guard !chunks.isEmpty else {
                            print("[AISummary] 요약할 텍스트가 없습니다.")
                            await send(.aiSummaryFailed(projectId: projectId))
                            return
                        }
                        
                        print("[AISummary] 1단계: \(chunks.count)개 청크로 분할")
                        
                        await send(.destination(.presented(.audioDetail(.aiSummary(.updateProgress(0.05, "1단계 요약 시작..."))))))
                        
                        var partialSummaries: [String] = []
                        let batchSize = 3
                        let totalBatches = (chunks.count + batchSize - 1) / batchSize
                        
                        for batchIndex in 0..<totalBatches {
                            let startIdx = batchIndex * batchSize
                            let endIdx = min(startIdx + batchSize, chunks.count)
                            let batchChunks = Array(chunks[startIdx..<endIdx])
                            
                            let batchSummaries = try await withThrowingTaskGroup(of: (Int, String).self) { group in
                                for (localIndex, chunk) in batchChunks.enumerated() {
                                    let globalIndex = startIdx + localIndex
                                    
                                    group.addTask {
                                        let q = AlanClient.Question(
                                                """
                                                다음을 1-2문장으로 핵심만 요약:
                                                
                                                \(chunk)
                                                """
                                        )
                                        
                                        var lastError: Error?
                                        for attempt in 1...2 {
                                            do {
                                                let answer = try await AlanClient.shared.question(q)
                                                print("[AISummary] 청크 \(globalIndex + 1) 완료")
                                                return (globalIndex, answer.content)
                                            } catch {
                                                lastError = error
                                                print("[AISummary] 청크 \(globalIndex + 1) 실패 (시도 \(attempt)/2)")
                                                if attempt < 2 {
                                                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                                                }
                                            }
                                        }
                                        throw lastError ?? AlanClient.Error.networkError(NSError(domain: "Unknown", code: -1))
                                    }
                                }
                                
                                var results: [(Int, String)] = []
                                for try await result in group {
                                    results.append(result)
                                }
                                return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
                            }
                            
                            partialSummaries.append(contentsOf: batchSummaries)
                            
                            let progress = 0.05 + (Double(endIdx) / Double(chunks.count)) * 0.4
                            await send(.destination(.presented(.audioDetail(.aiSummary(.updateProgress(
                                progress,
                                "1단계... \(endIdx)/\(chunks.count)"
                            ))))))
                            
                            if batchIndex < totalBatches - 1 {
                                try? await Task.sleep(nanoseconds: 500_000_000)
                            }
                        }
                        
                        print("[AISummary] 1단계 완료: \(partialSummaries.count)개 요약")
                        
                        let summaryGroups = stride(from: 0, to: partialSummaries.count, by: 5).map {
                            Array(partialSummaries[$0..<min($0 + 5, partialSummaries.count)])
                        }
                        
                        print("[AISummary] 2단계: \(summaryGroups.count)개 그룹으로 중간 요약")
                        
                        await send(.destination(.presented(.audioDetail(.aiSummary(.updateProgress(0.5, "2단계 통합 중..."))))))
                        
                        var intermediateSummaries: [String] = []
                        for (groupIndex, group) in summaryGroups.enumerated() {
                            let combinedGroup = group.joined(separator: " ")
                            
                            let q = AlanClient.Question(
                                    """
                                    다음 요약들을 2-3문장으로 통합:
                                    
                                    \(combinedGroup)
                                    """
                            )
                            
                            var lastError: Error?
                            for attempt in 1...2 {
                                do {
                                    let answer = try await AlanClient.shared.question(q)
                                    intermediateSummaries.append(answer.content)
                                    print("[AISummary] 2단계 그룹 \(groupIndex + 1) 완료")
                                    break
                                } catch {
                                    lastError = error
                                    print("[AISummary] 2단계 그룹 \(groupIndex + 1) 실패 (시도 \(attempt)/2)")
                                    if attempt < 2 {
                                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                                    }
                                }
                            }
                            
                            if intermediateSummaries.count <= groupIndex {
                                throw lastError ?? AlanClient.Error.networkError(NSError(domain: "IntermediateFailed", code: -1))
                            }
                            
                            let progress = 0.5 + (Double(groupIndex + 1) / Double(summaryGroups.count)) * 0.3
                            await send(.destination(.presented(.audioDetail(.aiSummary(.updateProgress(
                                progress,
                                "2단계... \(groupIndex + 1)/\(summaryGroups.count)"
                            ))))))
                            
                            try? await Task.sleep(nanoseconds: 500_000_000)
                        }
                        
                        print("[AISummary] 2단계 완료: \(intermediateSummaries.count)개 중간 요약")
                        
                        await send(.destination(.presented(.audioDetail(.aiSummary(.updateProgress(0.85, "최종 요약 생성 중..."))))))
                        
                        let finalInput = intermediateSummaries.joined(separator: " ")
                        
                        let maxFinalLength = 500
                        let truncatedInput: String
                        if finalInput.count > maxFinalLength {
                            let endIndex = finalInput.index(finalInput.startIndex, offsetBy: maxFinalLength)
                            truncatedInput = String(finalInput[..<endIndex])
                        } else {
                            truncatedInput = finalInput
                        }
                        
                        print("[AISummary] 최종 요약 입력 크기: \(truncatedInput.count) 문자")
                        
                        let finalQuestion = AlanClient.Question(
                                """
                                다음을 3줄로 핵심 정리:
                                
                                \(truncatedInput)
                                """
                        )
                        
                        var finalSummary: String?
                        var lastError: Error?
                        
                        for attempt in 1...3 {
                            do {
                                let finalAnswer = try await AlanClient.shared.question(finalQuestion)
                                finalSummary = finalAnswer.content
                                print("[AISummary] 최종 요약 완료")
                                break
                            } catch {
                                lastError = error
                                print("[AISummary] 최종 요약 실패 (시도 \(attempt)/3): \(error)")
                                if attempt < 3 {
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                }
                            }
                        }
                        
                        guard let summary = finalSummary else {
                            throw lastError ?? AlanClient.Error.networkError(NSError(domain: "FinalSummaryFailed", code: -1))
                        }
                        
                        await send(.destination(.presented(.audioDetail(.aiSummary(.updateProgress(0.95, "저장 중..."))))))
                        await send(.aiSummaryResponse(projectId: projectId, summary: summary))
                        
                        // Firebase 저장
                        if let ownerId {
                            let allProjects = try await projectLocalDataClient.fetchAll(context, ownerId)
                            guard let existingProject = allProjects.first(where: { $0.id == projectId }) else {
                                print("[AISummary] 프로젝트를 찾을 수 없음: \(projectId)")
                                return
                            }
                            
                            let updatedProject = ProjectPayload(
                                id: existingProject.id,
                                name: existingProject.name,
                                creationDate: existingProject.creationDate,
                                category: existingProject.category,
                                isFavorite: existingProject.isFavorite,
                                filePath: existingProject.filePath,
                                fileLength: existingProject.fileLength,
                                transcript: existingProject.transcript,
                                summary: summary,
                                ownerId: existingProject.ownerId,
                                syncStatus: existingProject.syncStatus,
                                remoteAudioPath: existingProject.remoteAudioPath
                            )
                            
                            try await firebaseClient.updateProject(ownerId, updatedProject)
                            try await projectLocalDataClient.update(context, projectId, nil, nil, nil, nil, summary)
                            
                            // 채팅방 프리뷰 업데이트
                            let base = summary
                                .replacingOccurrences(of: "\n", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            let short = base.count > 25 ? String(base.prefix(25)) : base
                            let preview = short + "의 방"
                            
                            try await firebaseClient.updateChatRoomPreview(
                                ownerId,
                                existingProject.id,
                                existingProject.name,
                                preview
                            )
                            
                            print("[AISummary] Firebase 저장 완료")
                        }
                        
                        await send(.destination(.presented(.audioDetail(.aiSummary(.updateProgress(1.0, "완료!"))))))
                        
                    } catch {
                        print("[AISummary] AI 요약 실패: \(error)")
                        await send(.aiSummaryFailed(projectId: projectId))
                    }
                }
                
            case let .aiSummaryResponse(projectId, summary):
                if var destination = state.destination,
                   case var .audioDetail(detail) = destination,
                   detail.aiSummary.projectId == projectId {
                    detail.aiSummary.summary = summary
                    detail.aiSummary.isLoading = false
                    
                    destination = .audioDetail(detail)
                    state.destination = destination
                }
                
                if let index = state.projects.firstIndex(where: { $0.id.uuidString == projectId}) {
                    state.projects[index].summary = summary
                }
                return .none
                
            case let .aiSummaryFailed(projectId):
                if var destination = state.destination,
                   case var .audioDetail(detail) = destination,
                   detail.aiSummary.projectId == projectId {
                    
                    detail.aiSummary.isLoading = false
                    detail.aiSummary.summary = "요약 생성에 실패했습니다."
                    
                    destination = .audioDetail(detail)
                    state.destination = destination
                }
                return .none
                
            case .destination(.presented(.audioDetail)):
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

extension ProjectListFeature {
    static func cleanupOrphanedStorageFiles(
        ownerId: String,
        remoteProjects: [ProjectPayload],
        fileCloudClient: FileCloudClient
    ) async {
        do {
            print("[ProjectList] 🧹 Storage 고아 파일 정리 시작")
            
            let validRemotePaths = Set(remoteProjects.compactMap { $0.remoteAudioPath })
            print("  - Firestore에 등록된 파일: \(validRemotePaths.count)개")
            for path in validRemotePaths {
                print("    ✅ \(path)")
            }
            
            let storagePath = "users/\(ownerId)/audio"
            let storageFiles = try await fileCloudClient.listFiles(storagePath)
            print("  - Storage에 실제 존재하는 파일: \(storageFiles.count)개")
            for path in storageFiles {
                print("    📦 \(path)")
            }
            
            let orphanedFiles = storageFiles.filter { !validRemotePaths.contains($0) }
            
            if orphanedFiles.isEmpty {
                print("[ProjectList] ✅ 고아 파일 없음 - Storage 정리 불필요")
                return
            }
            
            print("[ProjectList] 🗑️ 고아 파일 \(orphanedFiles.count)개 발견:")
            for path in orphanedFiles {
                print("    ❌ \(path)")
            }
            
            var deletedCount = 0
            for orphanedPath in orphanedFiles {
                do {
                    try await fileCloudClient.deleteFile(orphanedPath)
                    deletedCount += 1
                    print("[ProjectList] 🗑️ 고아 파일 삭제 완료: \(orphanedPath)")
                } catch {
                    print("[ProjectList] ⚠️ 고아 파일 삭제 실패 (계속 진행): \(orphanedPath) - \(error)")
                }
            }
            
            print("[ProjectList] ✅ Storage 고아 파일 정리 완료: \(deletedCount)/\(orphanedFiles.count)개 삭제")
            
        } catch {
            print("[ProjectList] ⚠️ Storage 고아 파일 정리 실패: \(error)")
        }
    }
}

fileprivate func splitTranscript(_ text: String, maxChunkLength: Int ) -> [String] {
    guard !text.isEmpty else {
        return []
    }
    
    var result: [String] = []
    var startIndex = text.startIndex
    
    while startIndex < text.endIndex {
        let endIndex = text.index(
            startIndex,
            offsetBy: maxChunkLength,
            limitedBy: text.endIndex
        ) ?? text.endIndex
        
        let chunk = String(text[startIndex..<endIndex])
        result.append(chunk)
        startIndex = endIndex
    }
    
    return result
}
