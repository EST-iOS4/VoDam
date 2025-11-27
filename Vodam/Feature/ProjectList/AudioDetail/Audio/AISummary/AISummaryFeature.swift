//
//  AISummaryFeature.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import ComposableArchitecture

@Reducer
struct AISummaryFeature {
    @ObservableState
    struct State: Equatable {
        var summary: String?
        var isLoading: Bool = false
        var transcript: String
        
        init(transcript: String) {
            self.transcript = transcript
            self.summary = nil
        }
    }
    
    enum Action {
        case summarizeButtonTapped
        case summaryResponse(String)
        case summaryFailed(Error)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .summarizeButtonTapped:
                state.isLoading = true
                let transcript = state.transcript
                
                return .run { send in
                    do {
                        // API 호출
                        let summary = try await generateSummary(transcript: transcript)
                        await send(.summaryResponse(summary))
                    } catch {
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
            }
        }
    }
    
    private func generateSummary(transcript: String) async throws -> String {
        
        try await Task.sleep(for: .seconds(2))
        
        return """
               📝 AI 요약
               
               이 문서의 주요 내용을 요약하면 다음과 같습니다:
               
               • 주요 주제 1
               • 주요 주제 2
               • 주요 주제 3
               
               전체 내용:
               \(transcript.prefix(200))...
               """
    }
}
