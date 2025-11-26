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
        var summary: String = "This is the AI summary content."
    }

    enum Action {
        
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
            }
            return .none
        }
    }
}
