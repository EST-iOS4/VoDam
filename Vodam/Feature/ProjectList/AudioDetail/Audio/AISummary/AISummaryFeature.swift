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
        
        var progress: Double = 0.0
        var progressMessage: String? = nil
        
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
        
        case updateProgress(Double, String)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .summarizeButtonTapped(let context):
                
                guard !state.isLoading else {
                    return .none
                }
                
                state.isLoading = true
                state.progress = 0.0
                state.progressMessage = "요약 준비 중..."
                return .none
                
            case .summaryResponse(let summary):
                state.isLoading = false
                state.summary = summary
                state.progress = 1.0
                state.progressMessage = "요약 완료!"
                return .none
                
            case .summaryFailed(let error):
                state.isLoading = false
                state.progress = 0.0
                state.progressMessage = nil
                print("AI 요약 실패: \(error)")
                state.summary = "요약 생성에 실패했습니다. 다시 시도해주세요."
                return .none
                
            case .summarySavedToFirebase:
                print("[AISummary] 요약본 Firebase 저장 완료")
                return .none
                
            case .summarySaveFailedToFirebase(let error):
                print("[AISummary] 요약본 Firebase 저장 실패 (계속 진행): \(error)")
                return .none
                
            case let .updateProgress(progress, message):
                state.progress = progress
                state.progressMessage = message
                return .none
            }
        }
    }
}
