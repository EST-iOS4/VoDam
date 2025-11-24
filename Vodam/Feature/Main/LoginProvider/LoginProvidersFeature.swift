import ComposableArchitecture
//
//  LoginProvidersFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//
import Foundation
import KakaoSDKAuth
import KakaoSDKUser

@Reducer
struct LoginProvidersFeature {

    @ObservableState
    struct State: Equatable {
    }
    
    enum Provider: Equatable {
        case apple
        case google
        case kakao
    }
    
    enum LoginError: Error {
        case notImplemented(String)
    }
    
    enum Action: Equatable {
        case providerTapped(Provider)
        
        enum Delegate: Equatable {
           case login(Bool, User?)
        }
        case delegate(Delegate)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
            case let .providerTapped(provider):
                return .run { send in
                    do {
                        let user: User
                        
                        switch provider {
                        case .kakao:
                            user = try await AuthService.loginWithKaKao()
                            
                        case .apple:
                            throw LoginError.notImplemented("Apple 로그인 미구현")
                            
                        case .google:
                            throw LoginError.notImplemented("Google 로그인 미구현")
                            
                        }
                        
                        await send(.delegate(.login(true, user)))
                    } catch {
                        print("로그인 실패: \(error)")
                        await send(.delegate(.login(false, nil)))
                    }
                    
                }
            case .delegate:
                return .none
            }
        }
    }
}
