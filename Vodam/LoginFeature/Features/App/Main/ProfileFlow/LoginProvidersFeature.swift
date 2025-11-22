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
    
    enum Action: Equatable {
        case appleTapped
        case googleTapped
        case kakaoTapped

        case loginResponese(TaskResult<User>)

        enum Delegate: Equatable {
            case loginFinished(User)
            case loginFailed(String)
        }
        case delegate(Delegate)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .appleTapped:
                return .none

            case .googleTapped:
                return .none

            case .kakaoTapped:
                return .run { send in
                    await send(.loginResponese(
                        TaskResult {
                            try await AuthService.loginWithKaKao()
                        }
                    ))
                }
                
            case let .loginResponese(.success(user)):
                return .send(.delegate(.loginFinished(user)))
                
            case let .loginResponese(.failure(error)):
                print("로그인 실패: \(error)")
                return .send(.delegate(.loginFailed(error.localizedDescription)))

            case .delegate:
                return .none
            }
        }
    }
}
