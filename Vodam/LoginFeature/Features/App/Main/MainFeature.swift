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
        @Presents var loginProviders: LoginProvidersFeature.State?
        @Presents var settings: SettingsFeature.State?
        
        //(선택) 현재 로그인한 사용자 캐싱하고 싶으면 여기에
        var currentUser: User?
    }
    
    enum Action: Equatable {
        case profileButtonTapped
        case profileFlow(PresentationAction<ProfileFlowFeature.Action>)
        
        case loginProviders(PresentationAction<LoginProvidersFeature.Action>)
        
        case settings(PresentationAction<SettingsFeature.Action>)
        
        case dismissProfileSheet
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .profileButtonTapped:
                state.profileFlow = ProfileFlowFeature.State()
                return .none
            
            case .profileFlow(.presented(.loginButtonTapped)):
                state.profileFlow = nil
                state.loginProviders = LoginProvidersFeature.State()
                // 2) 나중에 여기서 "로그인 화면 push"트리거 만들기
                return .none

            case .profileFlow(.presented(.cancelButtonTapped)):
                state.profileFlow = nil
                return .none
                
            case .dismissProfileSheet:
                state.profileFlow = nil
                return .none
                
            case let .loginProviders(.presented(.delegate(.kakaoLoginFinished(user)))):
                // 나중에 실제 로그인 성공/실패 처리 추가 예정
                state.loginProviders = nil
                state.currentUser = user
                state.settings = SettingsFeature.State(user: user)
                return .none
                
            case let .loginProviders(.presented(.delegate(.kakaoLoginFailed(message)))):
                print("Kakao login failed in MainFeautre: \(message)")
                return .none
                
            case .loginProviders:
                return .none
            
            case .profileFlow:
                return .none
                
            case .settings:
                return .none
            }
        }
        .ifLet(\.$profileFlow, action: \.profileFlow) {
            ProfileFlowFeature()
        }
        
        .ifLet(\.$loginProviders, action: \.loginProviders) {
            LoginProvidersFeature()
        }
        
        .ifLet(\.$settings, action: \.settings) {
            SettingsFeature()
        }
    }
}
