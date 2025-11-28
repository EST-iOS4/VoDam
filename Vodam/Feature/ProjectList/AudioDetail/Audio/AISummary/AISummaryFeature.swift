//
//  AISummaryFeature.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import ComposableArchitecture
import SwiftData

@Reducer
struct AISummaryFeature {
    @ObservableState
    struct State: Equatable {
        var summary: String?
        var isLoading: Bool = false
        var transcript: String
        var projectId: String
        var ownerId: String?
        
        init(
            transcript: String,
            savedSummary: String? = nil,
            projectId: String,
            ownerId: String?
        ) {
            self.transcript = transcript
            self.summary = savedSummary
            self.projectId = projectId
            self.ownerId = ownerId
        }
    }
    
    enum Action {
        case summarizeButtonTapped(ModelContext)
        case summaryResponse(String)
        case summaryFailed(Error)
        case summarySavedToFirebase
        case summarySaveFailedToFirebase(Error)
    }
    
    @Dependency(\.firebaseClient) var firebaseClient
    @Dependency(\.projectLocalDataClient) var projectLocalDataClient
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .summarizeButtonTapped(let context):
                
                if let existingSummary = state.summary, !existingSummary.isEmpty {
                    print("[AISummary] 기존 요약본 사용 - API 호출 생략")
                    return .none
                }
                
                state.isLoading = true
                let transcript = state.transcript
                let projectId = state.projectId
                let ownerId = state.ownerId
                
                return .run { [projectLocalDataClient, firebaseClient] send in
                    do {
                        // 텍스트가 너무 길면 앞부분만 사용
                        let maxLength = 2000
                        let textToSummarize = transcript.count > maxLength
                        ? String(transcript.prefix(maxLength)) + "...\n\n(문서의 일부입니다)"
                        : transcript
                        
                        print("[AISummary] Alan AI 호출 시작")
                        
                        let question = AlanClient.Question(
                            "다음 텍스트를 3개의 핵심 포인트로 3줄로 간결하게 요약해주세요:\n\n\(textToSummarize)"
                        )
                        
                        let answer = try await AlanClient.shared.question(question)
                        let summary = answer.content
                        
                        print("[AISummary] AI 요약 완료: \(summary.prefix(50))...")
                        
                        await send(.summaryResponse(summary))
                        
                        if let ownerId {
                            do {
                                print("[AISummary] Firebase에 요약본 저장 시작")
                                
                                // 로컬 DB에서 프로젝트 가져오기
                                let allProjects = try await projectLocalDataClient.fetchAll(context, ownerId)
                                
                                guard let existingProject = allProjects.first(where: { $0.id == projectId }) else {
                                    print("[AISummary] 프로젝트를 찾을 수 없음: \(projectId)")
                                    return
                                }
                                
                                // summary 필드 업데이트된 새 ProjectPayload 생성
                                let updatedProject = ProjectPayload(
                                    id: existingProject.id,
                                    name: existingProject.name,
                                    creationDate: existingProject.creationDate,
                                    category: existingProject.category,
                                    isFavorite: existingProject.isFavorite,
                                    filePath: existingProject.filePath,
                                    fileLength: existingProject.fileLength,
                                    transcript: existingProject.transcript,
                                    summary: summary,  // 새 요약본
                                    ownerId: existingProject.ownerId,
                                    syncStatus: existingProject.syncStatus,
                                    remoteAudioPath: existingProject.remoteAudioPath
                                )
                                
                                // Firebase 업데이트
                                try await firebaseClient.updateProject(ownerId, updatedProject)
                                
                                // 로컬 DB 업데이트
                                try await projectLocalDataClient.update(
                                    context,
                                    projectId,
                                    nil,  // name
                                    nil,  // isFavorite
                                    nil,  // transcript
                                    nil,  // syncStatus
                                    summary  // summary
                                )
                                
                                print("[AISummary] Firebase 저장 완료")
                                await send(.summarySavedToFirebase)
                                
                            } catch {
                                print("[AISummary] Firebase 저장 실패: \(error)")
                                await send(.summarySaveFailedToFirebase(error))
                            }
                        } else {
                            print("[AISummary] 비회원 - Firebase 저장 생략")
                        }
                        
                    } catch {
                        print("[AISummary] AI 요약 실패: \(error)")
                        await send(.summaryFailed(error))
                    }
                }
                
            case .summaryResponse(let summary):
                state.isLoading = false
                state.summary = summary
                return .none
                
            case .summaryFailed(let error):
                state.isLoading = false
                print("AI 요약 실패: \(error)")
                state.summary = "요약 생성에 실패했습니다. 다시 시도해주세요."
                return .none
                
            case .summarySavedToFirebase:
                print("[AISummary] 요약본 Firebase 저장 완료")
                return .none
                
            case .summarySaveFailedToFirebase(let error):
                print("[AISummary] 요약본 Firebase 저장 실패 (계속 진행): \(error)")
                // 저장 실패해도 사용자에게는 요약본 보여줌
                return .none
            }
        }
    }
}
