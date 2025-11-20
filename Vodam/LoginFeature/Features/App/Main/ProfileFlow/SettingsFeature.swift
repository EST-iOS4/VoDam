//
//  SettingsFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture

@Reducer
struct SettingsFeature {
    
    @ObservableState
    struct State: Equatable {
        var user: User
    }
    
    enum Action: Equatable {
        case profileImageChage
        case logoutTapped
        case deleteAccountTapped
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .profileImageChage:
                return .none
                
            case .logoutTapped:
                //나중에 로그아웃 처리
                return .none
                
            case .deleteAccountTapped:
                //나중에 실제 계정 삭제 처리
                return .none
            }
        }
    }
}
