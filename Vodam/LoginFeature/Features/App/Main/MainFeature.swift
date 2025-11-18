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
        
        //Presents SwiftUI의 @State 변수가
        @Presents var profileFlow: ProfileFlowFeature.State? = nil
        
    
        @Presents var loginProviders: LoginProvidersFeature.State?
    }
    
    enum Action: Equatable {
        case profileButtonTapped
        case profileFlow(PresentationAction<ProfileFlowFeature.Action>)
        
        case loginProviders(PresentationAction<LoginProvidersFeature.Action>)
        
        case dismissProfileSheet
        
//        case delegate(PresentationAction<ProfileFlowFeature.Action>)
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case shouldNavigateToLogin
            case didOpenProfileSheet
            case loginButtonTapped
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
            case .profileButtonTapped:
                state.profileFlow = ProfileFlowFeature.State()
                return .none
                
                
//            case .profileFlow(.presented(.loginButtonTapped)):
//                // 1) 로그인 안내 시트 닫기
//                
//                // 상태를 바꾸는 거는 순서랑 상관없이 동시에 그려요.
//                state.profileFlow = nil
//                state.loginProviders = LoginProvidersFeature.State()
//                // 2) 나중에 여기서 "로그인 화면 push"트리거 만들기
//                return .send(.delegate(.shouldNavigateToLogin))
                
            case .profileFlow(.presented(.loginButtonTapped)):
                return .send(.delegate(.loginButtonTapped))
                

                
            case .profileFlow(.presented(.cancelButtonTapped)):
                state.profileFlow = nil
                return .none
                
            case .dismissProfileSheet:
                state.profileFlow = nil
                return .none
                
            case .profileFlow:
                return .none
                
            case .loginProviders:
                // 나중에 실제 로그인 성공/실패 처리 추가 예정
                return .none
                
            case .delegate:
                return .none //멈추는것, Scope씌어서 관여를 안한다. <
                
            }
        }
        .ifLet(\.$profileFlow, action: \.profileFlow) {
            ProfileFlowFeature()
        }
        
        .ifLet(\.$loginProviders, action: \.loginProviders) {
            LoginProvidersFeature()
        }
    }
}
