//
//  MainFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct MainFeature {

    @ObservableState
    struct State: Equatable {
        @Presents var profileFlow: ProfileFlowFeature.State?
        @Presents var loginProviders: LoginProvidersFeature.State?
        @Presents var settings: SettingsFeature.State?

        // 현재 로그인한 사용자 (nil 비로그인)
        var currentUser: User?
    }

    enum AuthOperation: Equatable {
        case login(Bool)
        case logout(Bool)
        case deleteAccount(Bool)
    }

    enum Action: Equatable {
        case profileButtonTapped
        case profileFlow(PresentationAction<ProfileFlowFeature.Action>)
        case loginProviders(PresentationAction<LoginProvidersFeature.Action>)
        case settings(PresentationAction<SettingsFeature.Action>)
        case dismissProfileSheet

        case authOperationResponse(AuthOperation)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .profileButtonTapped:
                if let user = state.currentUser {
                    state.settings = SettingsFeature.State(user: user)
                } else {
                    state.profileFlow = ProfileFlowFeature.State()
                }
                return .none

            case .profileFlow(.presented(.guestButtonTapped)):
                state.profileFlow = nil
                state.settings = SettingsFeature.State(user: nil)
                return .none

            case .profileFlow(.presented(.loginButtonTapped)):
                state.profileFlow = nil
                state.loginProviders = LoginProvidersFeature.State()
                return .none

            case .profileFlow(.presented(.cancelButtonTapped)):
                state.profileFlow = nil
                return .none

            case .dismissProfileSheet:
                state.profileFlow = nil
                return .none

            case .loginProviders(
                .presented(.delegate(.loginFinished(let user)))
            ):
                state.loginProviders = nil
                state.currentUser = user
                state.settings = SettingsFeature.State(user: user)
                return .send(.authOperationResponse(.login(true)))

            case .loginProviders(
                .presented(.delegate(.loginFailed(let message)))
            ):
                print("Kakao login failed in MainFeautre: \(message)")
                return .send(.authOperationResponse(.login(false)))

            case .settings(.presented(.loginButtonTapped)):
                state.settings = nil
                state.loginProviders = LoginProvidersFeature.State()
                return .none

            //로그아웃
            case .settings(.presented(.logoutTapped)):
                return .run { send in
                    do {
                        try await AuthService.logout()
                        print("로그아웃 성공")
                        await send(.authOperationResponse(.logout(true)))
                    } catch {
                        print("로그아웃 실패:\(error)")
                        await send(
                            .authOperationResponse(.logout(false))
                        )
                    }
                }

            // 회원탈퇴( 로그아웃 + 정보 삭제)
            case .settings(.presented(.deleteAccountConfirmed)):
                return .run { send in
                    do {
                        try await AuthService.deleteAccount()
                        // firebase 사용자 데이터 삭제 넣기
                        await send(
                            .authOperationResponse(.deleteAccount(true))
                        )
                    } catch {
                        await send(
                            .authOperationResponse(.deleteAccount(false))
                        )

                    }
                }

            case .authOperationResponse(let operation):
                switch operation {
                case .login:
                    return .none

                case .logout(let isSuccess):
                    if isSuccess {
                        state.currentUser = nil
                    }
                    state.settings?.alert = AlertState {
                        TextState(isSuccess ? "로그아웃 성공" : "로그아웃 실패")
                    } actions: {
                        ButtonState(
                            action: isSuccess
                                ? .confirmLogoutSuccess : .confirmLogoutFailure
                        ) {
                            TextState("확인")
                        }
                    } message: {
                        TextState(isSuccess ? "로그아웃 되었습니다." : "로그아웃에 실패했습니다")
                    }
                    return .none

                case .deleteAccount(let isSuccess):
                    if isSuccess {
                        state.currentUser = nil
                    }
                    state.settings?.alert = AlertState {
                        TextState(isSuccess ? "회원 탈퇴 완료" : "탈퇴 실패")
                    } actions: {
                        ButtonState(
                            action: isSuccess
                                ? .confirmDeleteSuccess : .confirmDeleteFailure
                        ) {
                            TextState("확인")
                        }
                    } message: {
                        TextState(
                            isSuccess ? "회원 탈퇴가 완료되었습니다" : "회원 탈퇴에 실패했습니다."
                        )
                    }
                    return .none
                }

            case .settings(
                .presented(.alert(.presented(.confirmLogoutSuccess)))
            ):
                state.settings = SettingsFeature.State(user: nil)
                return .none

            case .settings(
                .presented(.alert(.presented(.confirmLogoutFailure)))
            ):
                return .none

            case .settings(
                .presented(.alert(.presented(.confirmDeleteSuccess)))
            ):
                state.settings = SettingsFeature.State(user: nil)
                return .none

            case .settings(
                .presented(.alert(.presented(.confirmDeleteFailure)))
            ):
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
