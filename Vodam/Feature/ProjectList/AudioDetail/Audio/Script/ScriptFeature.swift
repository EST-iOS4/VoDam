//
//  ScriptFeature.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import ComposableArchitecture

@Reducer
struct ScriptFeature {
    @ObservableState
    struct State: Equatable {
        var text: String
        
        init(text: String = "This is the script content.") {
                    self.text = text
                }
    }

    enum Action {
        case setText(String)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .setText(let text):
                state.text = text
                return .none
            }
        }
    }
}
