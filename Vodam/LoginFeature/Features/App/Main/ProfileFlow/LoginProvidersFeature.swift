//
//  LoginProvidersFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//
import KakaoSDKAuth
import KakaoSDKUser
import KakaoSDKCommon
import ComposableArchitecture

@Reducer
struct LoginProvidersFeature {
    @ObservableState
    struct State: Equatable {
    }
    
    enum Action: Equatable {
        case appleTapped
        case googleTapped
        case kakaoTapped
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .appleTapped:
                return .none
                
            case .googleTapped:
                return .none
                
            case  .kakaoTapped:
                return .none
            }
        }
    }
}
