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

        var currentUser: User?

        var recording = RecordingFeature.State()
        var fileButton = FileButtonFeature.State()
        var pdfButton = PDFButtonFeature.State()
    }

    enum Action: Equatable {
        case profileButtonTapped
        case profileFlow(PresentationAction<ProfileFlowFeature.Action>)
        case loginProviders(PresentationAction<LoginProvidersFeature.Action>)
        case settings(PresentationAction<SettingsFeature.Action>)
        case dismissProfileSheet

        case recording(RecordingFeature.Action)
        case fileButton(FileButtonFeature.Action)
        case pdfButton(PDFButtonFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.recording, action: \.recording) {
            RecordingFeature()
        }

        Scope(state: \.fileButton, action: \.fileButton) {
            FileButtonFeature()
        }

        Scope(state: \.pdfButton, action: \.pdfButton) {
            PDFButtonFeature()
        }

        Reduce { state, action in
            switch action {

            case .profileButtonTapped:
                if let user = state.currentUser {
                    state.settings = SettingsFeature.State(user: user)
                } else {
                    state.profileFlow = ProfileFlowFeature.State()
                }
                return .none
                
            case let .settings(.presented(.delegate(.userUpdated(user)))):
                state.currentUser = user
                return .none
                
            case let .settings(.presented(.delegate(.accountCleared(isSuccess)))):
                if isSuccess {
                    state.currentUser = nil
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

            //MARK: 통합 로그인 (카카오/애플/구글 통합)
            case .loginProviders(
                .presented(.delegate(.login(let isSuccess, let user)))
            ):
                if isSuccess, let user {
                    state.currentUser = user
                    state.settings = SettingsFeature.State(user: user)
                    state.loginProviders = nil
                } else {
                    print("로그인 실패")
                }
                return .none

            case .settings(.presented(.loginButtonTapped)):
                state.settings = nil
                state.loginProviders = LoginProvidersFeature.State()
                return .none

//            case .settings(
//                .presented(.alert(.presented(.confirmLogoutSuccess)))
//            ):
//                state.settings = SettingsFeature.State(user: nil)
//                return .none
//
//            case .settings(
//                .presented(.alert(.presented(.confirmLogoutFailure)))
//            ):
//                return .none
//
//            case .settings(
//                .presented(.alert(.presented(.confirmDeleteSuccess)))
//            ):
//                state.settings = SettingsFeature.State(user: nil)
//                return .none
//
//            case .settings(
//                .presented(.alert(.presented(.confirmDeleteFailure)))
//            ):
//                return .none

            case .loginProviders:
                return .none

            case .profileFlow:
                return .none

            case .settings:
                return .none

            case .recording, .fileButton, .pdfButton:
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
