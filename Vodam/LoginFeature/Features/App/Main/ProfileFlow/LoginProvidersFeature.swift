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

        case kakaoLoginSucceeded(User)
        case kakaoLoginFailed(String)

        enum Delegate: Equatable {
            case kakaoLoginFinished(User)
            case kakaoLoginFailed(String)
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
                    do {
                        let user = try await AuthService.loginWithKaKao()
                        await send(.kakaoLoginSucceeded(user))
                    } catch {
                        await send(.kakaoLoginFailed(error.localizedDescription))
                    }
                }
            case .kakaoLoginSucceeded(let user):
                return .send(.delegate(.kakaoLoginFinished(user)))

            case .kakaoLoginFailed(let message):
                print("Kakao login failed: \(message)")
                return .send(.delegate(.kakaoLoginFailed(message)))

            case .delegate:
                return .none
            }
        }
    }
}
