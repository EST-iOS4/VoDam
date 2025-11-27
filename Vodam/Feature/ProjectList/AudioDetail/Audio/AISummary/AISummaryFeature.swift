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
        
        init(transcript: String, savedSummary: String? = nil) {
            self.transcript = transcript
            self.summary = savedSummary
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
                        // 텍스트가 너무 길면 앞부분만 사용
                        let maxLength = 2000
                        let textToSummarize = transcript.count > maxLength
                        ? String(transcript.prefix(maxLength)) + "...\n\n(문서의 일부입니다)"
                        : transcript
                        
                        let question = AlanClient.Question(
                            "다음 텍스트를 3개의 핵심 포인트로 3줄로 간결하게 요약해주세요:\n\n\(textToSummarize)"
                        )
                        
                        let answer = try await AlanClient.shared.question(question)
                        
                        await send(.summaryResponse(answer.content))
                        
                    } catch {
                        print("AI 요약 실패: \(error)")
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
}
