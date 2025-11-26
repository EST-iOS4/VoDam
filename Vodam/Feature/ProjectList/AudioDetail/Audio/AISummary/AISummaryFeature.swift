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
        var summary: String
        
        init(summary: String = "This is the AI summary content.") {
            self.summary = summary
        }
    }
    
    enum Action {
        case setSummary(String)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .setSummary(text):
                state.summary = text
                return .none
            }
        }
    }
}
