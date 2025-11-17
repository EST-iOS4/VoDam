//
//  MainFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture

@Reducer
struct MainFeature {
    
    @ObservableState
    struct State: Equatable {
        @Presents var profileFlow: ProfileFlowFeature.State?
    }
    
    enum Action: Equatable {
        case profileButtonTapped
        case profileFlow(PresentationAction<ProfileFlowFeature.Action>)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
            case .profileButtonTapped:
                state.profileFlow = ProfileFlowFeature.State()
                return .none
                
            case .profileFlow(.presented(.loginButtonTapped)):
                // 1) 로그인 안내 시트 닫기
                state.profileFlow = nil
                // 2) 나중에 여기서 "로그인 화면 push"트리거 만들기
                return .none
                
            case .profileFlow:
                return .none
            }
        }
        .ifLet(\.$profileFlow, action: \.profileFlow) {
            ProfileFlowFeature()
        }
    }
}
