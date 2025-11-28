//
//  AppFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    
    @ObservableState
    struct State: Equatable {
        var startTab: State.Tab = .main
        
        var user: User? = nil
        
        var main = MainFeature.State()
        var list = ProjectListFeature.State()
        var chat = ChattingListFeature.State(
            chattingList: [
                ChattingInfo(
                    id: "1",
                    title: "프로젝트 1",
                    content: "프로젝트 대화 내용프로젝트 대화 내용...",
                    recentEditedDate: Date()
                ),
                ChattingInfo(
                    id: "2",
                    title: "프로젝트 2",
                    content: "TCA 요약에 대한 대화 내용...",
                    recentEditedDate: Date()
                ),
            ]
        )
        
        enum Tab: Equatable {
            case main
            case list
            case chat
        }
    }
    
    enum Action {
        case onAppear
        
        case setUser(User?)
        
        case startTab(State.Tab)
        case main(MainFeature.Action)
        case list(ProjectListFeature.Action)
        case chat(ChattingListFeature.Action)
        
    }
    @Dependency(\.userStorageClient) var userStorageClient
    
    var body: some Reducer<State, Action> {
        Scope(state: \.main, action: \.main) {
            MainFeature()
        }
        
        Scope(state: \.list, action: \.list) {
            ProjectListFeature()
        }
        
        Scope(state: \.chat, action: \.chat) {
            ChattingListFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [userStorageClient] send in
                    let storedUser = await userStorageClient.load()
                    await send(.setUser(storedUser))
                }
                
            case .setUser(let user):
                state.user = user
                state.main.currentUser = user
                state.list.currentUser = user
                return .none
                
            case .startTab(let tab):
                state.startTab = tab
                return .none
                
            case .main(.userLoaded(let user)):
                state.user = user
                state.list.currentUser = user
                return .none
                
            case .main(.settings(.presented(.delegate(.logoutCompleted)))):
                state.user = nil
                state.main.currentUser = nil
                state.list.currentUser = nil
                return .none
                
            case .main(
                .settings(.presented(.delegate(.deleteAccountCompleted)))
            ):
                state.user = nil
                state.main.currentUser = nil
                state.list.currentUser = nil
                return .none
                
            case .main(.delegate(.projectSaved)):
                return .send(.list(.refreshProjects))
            
            case .main:
                return .none
                
            case .list:
                return .none
                
            case .chat:
                return .none
            }
        }
    }
}
