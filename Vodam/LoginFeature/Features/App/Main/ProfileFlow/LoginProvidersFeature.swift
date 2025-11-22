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
    
    enum KakaoLoginResult: Equatable {
        case success(User)
        case failure(String)
    }

    enum Action: Equatable {
        case appleTapped
        case googleTapped
        case kakaoTapped

        case kakaoLoginResponse(KakaoLoginResult)

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
                        await send(.kakaoLoginResponse(.success(user)))
                    } catch {
                        await send(.kakaoLoginResponse(.failure(error.localizedDescription)))
                    }
                }
                
            case let .kakaoLoginResponse(result):
                switch result {
                case let .success(user):
                    return .send(.delegate(.kakaoLoginFinished(user)))
                    
                case let .failure(message):
                    print("Kakao 로그인 실패: \(message)")
                    return .send(.delegate(.kakaoLoginFailed(message)))
                }
              

            case .delegate:
                return .none
            }
        }
    }
}
