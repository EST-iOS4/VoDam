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
        case loginButtonTapped // 로그인 하러 가기
        case cancelButtonTapped // x버튼
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loginButtonTapped:
                //실제 동작은 MainFeature에서 -> .profileFlow 액션으로 받음
                return .none
                
            case .cancelButtonTapped:
                //실제 동작은 MainFeature에서 -> .profileFlow 액션으로 받음
                return .none
            }
        }
    }
}
