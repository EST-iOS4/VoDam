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
        
        case onAppear
        case userLoaded(User?)
        
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case projectSaved(String)      // 프로젝트 저장 완료
            case syncCompleted(String)     // 동기화 완료
            case userLoggedIn(User)        // 로그인 완료
        }
    }
    
    @Dependency(\.userStorageClient) var userStorageClient
    
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
            case .onAppear:
                return .run { send in
                    let user = await userStorageClient.load()
                    await send(.userLoaded(user))
                }
                
            case .userLoaded(let user):
                state.currentUser = user
                return .none
                
            case .profileButtonTapped:
                if let user = state.currentUser {
                    state.settings = SettingsFeature.State(user: user)
                } else {
                    state.profileFlow = ProfileFlowFeature.State()
                }
                return .none
                
            case .settings(.presented(.delegate(.userUpdated(let user)))):
                state.currentUser = user
                return .run { _ in
                    await userStorageClient.save(user)
                }
                
            case .settings(
                .presented(.delegate(.loggedOut(let isSuccess)))
            ):
                if isSuccess {
                    let ownerId = state.currentUser?.ownerId
                    state.currentUser = nil
                    return .run { _ in
                        await userStorageClient.clear()
                    }
                    // 재로그인 시 데이터를 다시 볼 수 있도록 유지
                }
                return .none
                
            case .settings(
                .presented(.delegate(.accountDeleted(let isSuccess)))
            ):
                if isSuccess {
                    state.currentUser = nil
                    return .run { _ in
                        await userStorageClient.clear()
                    }
                }
                return .none
                
            case .profileFlow(.presented(.guestButtonTapped)):
                state.profileFlow = nil
                state.settings = SettingsFeature.State(user: nil)
                return .run { _ in
                    await userStorageClient.clear()
                }
                
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
                
                // 통합 로그인 (카카오/애플/구글 통합)
            case .loginProviders(
                .presented(.delegate(.login(let isSuccess, let user)))
            ):
                if isSuccess, let user {
                    state.currentUser = user
                    state.settings = SettingsFeature.State(user: user)
                    state.loginProviders = nil
                    
                    return .run { send in
                        await userStorageClient.save(user)
                        await send(.delegate(.userLoggedIn(user)))
                    }
                } else {
                    // 로그인 실패 또는 취소 (이미 LoginProvidersFeature에서 로그 출력)
                }
                return .none
                
            case .settings(.presented(.loginButtonTapped)):
                state.settings = nil
                state.loginProviders = LoginProvidersFeature.State()
                return .none

            case .recording(.delegate(let delegateAction)):
                switch delegateAction {
                case .projectSaved(let projectId):
                    return .send(.delegate(.projectSaved(projectId)))
                case .syncCompleted(let projectId):
                    return .send(.delegate(.syncCompleted(projectId)))
                }

            case .fileButton(.delegate(let delegateAction)):
                switch delegateAction {
                case .projectSaved(let projectId):
                    return .send(.delegate(.projectSaved(projectId)))
                case .syncCompleted(let projectId):
                    return .send(.delegate(.syncCompleted(projectId)))
                }

            case .pdfButton(.delegate(let delegateAction)):
                switch delegateAction {
                case .projectSaved(let projectId):
                    return .send(.delegate(.projectSaved(projectId)))
                case .syncCompleted(let projectId):
                    return .send(.delegate(.syncCompleted(projectId)))
                }
                
            case .loginProviders:
                return .none
                
            case .profileFlow:
                return .none
                
            case .settings:
                return .none
                
            case .recording, .fileButton, .pdfButton:
                return .none
                
            case .delegate:
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
