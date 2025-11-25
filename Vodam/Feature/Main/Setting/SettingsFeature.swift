//
//  SettingsFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import Foundation
import PhotosUI
import SwiftUI

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var user: User?

        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action: Equatable {
        case loginButtonTapped
        case logoutTapped
        case deleteAccountTapped

        case deleteAccountConfirmed
        case logoutConfirmed
        case logoutFinished(Bool)
        case deleteAccountFinished(Bool)

        case profileImagePicked(Data)
        case photoPickerItemChanged(PhotosPickerItem?)

        case alert(PresentationAction<Alert>)

        case delegate(Delegate)

        enum Delegate: Equatable {
            case userUpdated(User)
            case accountCleared(Bool)
        }

        enum Alert: Equatable {
            case deleteAccountConfirmed
            case logoutConfirmed
        }
    }

    @Dependency(\.googleAuthClient) var googleAuthClient
    @Dependency(\.kakaoAuthClient) var kakaoAuthClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {

            case .loginButtonTapped:
                return .none

            case .logoutTapped:
                state.alert = AlertState {
                    TextState("로그아웃")
                } actions: {
                    ButtonState(
                        role: .destructive,
                        action: .logoutConfirmed
                    ) {
                        TextState("로그아웃")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("정말 로그아웃 하시겠습니까?")
                }
                return .none

            case .logoutConfirmed:
                guard let user = state.user else {
                    return .send(.logoutFinished(false))
                }

                switch user.provider {
                case .kakao:
                    return .run { send in
                        do {
                            try await kakaoAuthClient.logout()
                            await send(.logoutFinished(true))
                        } catch {
                            print("카카오 로그아웃 실패: \(error)")
                            await send(.logoutFinished(false))
                        }
                    }

                case .google:
                    return .run { [googleAuthClient] send in
                        await MainActor.run {
                            googleAuthClient.signOut()
                        }
                        await send(.logoutFinished(true))
                    }

                case .apple:
                    return .send(.logoutFinished(false))
                }

            case .logoutFinished(let isSuccess):
                if isSuccess {
                    state.user = nil
                    return .send(.delegate(.accountCleared(true)))
                } else {
                    print("로그아웃 실패")
                    return .send(.delegate(.accountCleared(false)))
                }

            case .deleteAccountTapped:
                state.alert = AlertState {
                    TextState("회원 탈퇴")
                } actions: {
                    ButtonState(
                        role: .destructive,
                        action: .deleteAccountConfirmed
                    ) {
                        TextState("탈퇴")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                } message: {
                    TextState("정말로 탈퇴하시겠습니까?\n모든 데이터가 삭제되며 복구할 수 없습니다.")
                }
                return .none

            case .deleteAccountConfirmed:
                guard let user = state.user else {
                    return .send(.deleteAccountFinished(false))
                }

                switch user.provider {
                case .kakao:
                    return .run { send in
                        do {
                            try await kakaoAuthClient.deleteAccount()
                            await send(.deleteAccountFinished(true))
                        } catch {
                            print("카카오 회원 탈퇴 실패: \(error)")
                            await send(.deleteAccountFinished(false))
                        }
                    }

                case .google:
                    return .run { send in
                        do {
                            try await googleAuthClient.disconnect()
                            await send(.deleteAccountFinished(true))
                        } catch {
                            print("구글 계정 연결 해제 실패: \(error)")
                            await send(.deleteAccountFinished(false))
                        }
                    }

                case .apple:
                    return .send(.deleteAccountFinished(false))
                }

            case .deleteAccountFinished(let isSuccess):
                if isSuccess {
                    state.user = nil
                    return .send(.delegate(.accountCleared(true)))
                } else {
                    print("회원 탈퇴 실패")
                    return .send(.delegate(.accountCleared(false)))
                }

            case .photoPickerItemChanged(let item):
                guard let item, state.user != nil else {
                    return .none
                }

                return .run { send in
                    do {
                        guard
                            let data = try await item.loadTransferable(
                                type: Data.self
                            )
                        else {
                            return
                        }

                        guard let uiImage = UIImage(data: data) else {
                            return
                        }

                        guard
                            let resizedImage = await uiImage.resized(
                                toWidth: 200
                            )
                        else {
                            return
                        }

                        guard
                            let compressedData = resizedImage.jpegData(
                                compressionQuality: 0.5
                            )
                        else {
                            return
                        }

                        await send(.profileImagePicked(compressedData))
                    } catch {
                        print("프로필 이미지 변경 실패: \(error)")
                    }
                }

            case .profileImagePicked(let data):
                guard var user = state.user else {
                    return .none
                }

                user.localProfileImageData = data
                state.user = user

                return .send(.delegate(.userUpdated(user)))

            case .delegate:
                return .none

            case .alert(.presented(.deleteAccountConfirmed)):
                return .send(.deleteAccountConfirmed)

            case .alert(.presented(.logoutConfirmed)):
                return .send(.logoutConfirmed)

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
