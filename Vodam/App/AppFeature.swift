//
//  AppFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture

@Reducer
struct AppFeature {
    
    @ObservableState
    struct State: Equatable {
        var main = MainFeature.State()
    }
    
    enum Action: Equatable {
        case main(MainFeature.Action)
    }
    
    var body: some Reducer<State, Action> {
        Scope(state: \.main, action: \.main) {
            MainFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .main:
                return .none
            @unknown default:
                return .none
            }
        }
    }
}
