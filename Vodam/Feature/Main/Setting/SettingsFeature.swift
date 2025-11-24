//
//  SettingsFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import Foundation

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var user: User?

        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action: Equatable {
//        case profileImageChange
        case loginButtonTapped
        case logoutTapped
        case deleteAccountTapped
        case deleteAccountConfirmed
        case profileImagePicked(Data)
        
        case alert(PresentationAction<Alert>)
        
        enum Delegate: Equatable {
            case userUpdated(User)
        }
        case delegate(Delegate)

        enum Alert: Equatable {
            case confirmLogoutSuccess
            case confirmLogoutFailure
            case confirmDeleteSuccess
            case confirmDeleteFailure
            case deleteAccountConfirmed
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
                
//            case .profileImageChange:
//                return .none

            case .loginButtonTapped:
                return .none

            case .logoutTapped:
                //MainFeature에서 처리
                return .none

            case .deleteAccountTapped:
                state.alert = AlertState {
                    TextState("회원 탈퇴")
                } actions: {
                    ButtonState(role: .destructive, action: .deleteAccountConfirmed) {
                        TextState("탈퇴")
                    }
                    ButtonState(role: .cancel){
                        TextState("취소")
                    }
                } message: {
                    TextState("정말로 탈퇴하시겠습니까?\n모든 데이터가 삭제되며 복구할 수 없습니다.")
                }
                return .none

            case .deleteAccountConfirmed:
                // MainFeature에서 실제 탈퇴 처리
                return .none
                
            case let .profileImagePicked(Data):
                guard var user = state.user else {
                    return .none
                }
                
                user.localProfileImageData = Data
                state.user = user
                
                return .send(.delegate(.userUpdated(user)))
                
            case .delegate:
                return .none
                
            case .alert(.presented(.deleteAccountConfirmed)):
                return .send(.deleteAccountConfirmed)

            case .alert(.presented(.confirmLogoutSuccess)):
                return .none
                
            case .alert(.presented(.confirmLogoutFailure)):
                return .none
                
            case .alert(.presented(.confirmDeleteSuccess)):
                return .none
                
            case .alert(.presented(.confirmDeleteFailure)):
                return .none
                
            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
