//
//  LoginProvidersFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//
import ComposableArchitecture
import Foundation

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
    
    @Dependency(\.kakaoAuthClient) var kakaoAuthClient
    @Dependency(\.googleAuthClient) var googleAuthClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
            case let .providerTapped(provider):
                return .run { send in
                    do {
                        let user: User
                        
                        switch provider {
                        case .kakao:
                            user = try await kakaoAuthClient.login()
                            
                        case .apple:
                            throw LoginError.notImplemented("Apple 로그인 미구현")
                            
                        case .google:
                            user = try await googleAuthClient.login()
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
