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
        // 나중에 넣을 예정
    }
    
    enum Action: Equatable {
       case loginButtonTapped
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loginButtonTapped:
                //지금 여기서 아무 것도 안 함
                //실제 동작은 MainFeature에서 -> .profileFlow 액션으로 받음
                return .none
            }
        }
    }
}
