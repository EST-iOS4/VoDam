//
//  MainFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture

@Reducer
struct MainFeature {
    
    @ObservableState // @Presents : Sheet나 NavigationDestination을 띄우는 상태
    struct State: Equatable { //MainFeature의 State
        @Presents var profileFlow: ProfileFlowFeature.State? // ProfileFlowFeature.State에 따른 profileFlow의 State
    
        @Presents var loginProviders: LoginProvidersFeature.State? // LoginProvidersFeature.State에 따른 loginProviders의 State
        
        var recording = RecordingFeature.State()
        var fileButton = FileButtonFeature.State()
        var pdfButton = PDFButtonFeature.State()

    }
    
    enum Action: Equatable { //MainFeature의 Action
        
        case recording(RecordingFeature.Action)
        
        case fileButton(FileButtonFeature.Action)
        
        case pdfButton(PDFButtonFeature.Action)

        
        case profileButtonTapped
        case profileFlow(PresentationAction<ProfileFlowFeature.Action>)
        
        case loginProviders(PresentationAction<LoginProvidersFeature.Action>)
        
        case dismissProfileSheet
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
            case .profileButtonTapped:
                state.profileFlow = ProfileFlowFeature.State() //profileFlow state에 ProfileFlowFeature State를 전달
                return .none
                
            case .profileFlow(.presented(.loginButtonTapped)): //profileFlow의 내부에서 State가 loginButtonTapped 인 경우
                // 1) 로그인 안내 시트 닫기
                state.profileFlow = nil
                state.loginProviders = LoginProvidersFeature.State()
                // 2) 나중에 여기서 "로그인 화면 push"트리거 만들기
                return .none
                
            case .profileFlow(.presented(.cancelButtonTapped)): //cancelButtonTapped인 경우
                state.profileFlow = nil
                return .none
                
            case .dismissProfileSheet:
                state.profileFlow = nil
                return .none
                
            case .profileFlow:
                return .none
                
            case .loginProviders:
                // 나중에 실제 로그인 성공/실패 처리 추가 예정
                return .none
                
            case .recording, .fileButton, .pdfButton:
                            return .none
            }

        }
        Scope(state: \.recording, action: \.recording) {
            RecordingFeature()
        }
        Scope(state: \.fileButton, action: \.fileButton) {
                    FileButtonFeature()
                }

        Scope(state: \.pdfButton, action: \.pdfButton) {
                    PDFButtonFeature()
                }
        .ifLet(\.$profileFlow, action: \.profileFlow) {
            ProfileFlowFeature() //Reducer
        }
        .ifLet(\.$loginProviders, action: \.loginProviders) {
            LoginProvidersFeature() //Reducer
        }
    }
}
