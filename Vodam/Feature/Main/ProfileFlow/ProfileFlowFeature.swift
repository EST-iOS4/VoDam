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
        
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case dismiss
            case loginRequested
            case guestSelected
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loginButtonTapped:
                return .send(.delegate(.loginRequested))
                
            case .cancelButtonTapped:
                return .send(.delegate(.dismiss))
                
            case .guestButtonTapped:
                return .send(.delegate(.guestSelected))
                
            case .delegate:
                return .none
            }
        }
    }
}
