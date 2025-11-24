//
//  ProfileFlowFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture

@Reducer
struct ProfileFlowFeature {
    
    @ObservableState
    struct State: Equatable {
    }
    
    enum Action: Equatable {
        case loginButtonTapped
        case cancelButtonTapped
        case guestButtonTapped
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loginButtonTapped:
                return .none
                
            case .cancelButtonTapped:
                return .none
                
            case .guestButtonTapped:
                return .none
            }
        }
    }
}
