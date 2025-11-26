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
        var text: String = "This is the script content."
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
