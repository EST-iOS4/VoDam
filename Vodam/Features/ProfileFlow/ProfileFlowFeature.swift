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
        // 나중에 로그인 액션 넣을 예정
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
                .none
        }
    }
}
