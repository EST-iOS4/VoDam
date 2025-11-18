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
        var main = ProjectListFeature.State()/*MainFeature.State()*/
    }
    
    enum Action {
        case main(ProjectListFeature.Action)
        
    }
    
    var body: some Reducer<State, Action> {
        Scope(state: \.main, action: \.main) {
            ProjectListFeature()
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
