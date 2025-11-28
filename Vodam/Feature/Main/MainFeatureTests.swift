//
//  MainFeatureTests.swift
//  VodamTests
//
//  Created by 이건준 on 11/25/25.
//

import Testing
import ComposableArchitecture
@testable import Vodam

@MainActor
@Suite
struct MainFeatureTests {
    
    // MARK: - Helpers
    
    private func makeUser() -> User {
        return User(
            name: "Vodam",
            email: nil,
            provider: .kakao,
            profileImageURL: nil
        )
    }
    
    // MARK: - 프로필 버튼 탭
    
    @Test
    func 비로그인_상태에서_프로필버튼을_탭하면_profileFlow가_열리고_settings는_nil이다() async {
        let store = TestStore(
            initialState: MainFeature.State(
                currentUser: nil
            ),
            reducer: { MainFeature() }
        )
        
        await store.send(.profileButtonTapped) {
            $0.profileFlow = ProfileFlowFeature.State()
            $0.settings = nil
        }
    }
    
    @Test
    func 로그인_상태에서_프로필버튼을_탭하면_settings가_열리고_profileFlow는_nil이다() async {
        let user = makeUser()
        
        let store = TestStore(
            initialState: MainFeature.State(
                currentUser: user
            ),
            reducer: { MainFeature() }
        )
        
        await store.send(.profileButtonTapped) {
            $0.settings = SettingsFeature.State(user: user)
            $0.profileFlow = nil
        }
    }
    
    // MARK: - ProfileFlow 액션
    
    @Test
    func 프로필플로우에서_게스트선택시_profileFlow는_닫히고_settings_guest가_열린다() async {
        let store = TestStore(
            initialState: MainFeature.State(
                profileFlow: ProfileFlowFeature.State()
            ),
            reducer: { MainFeature() }
        )
        
        await store.send(.profileFlow(.presented(.guestButtonTapped))) {
            $0.profileFlow = nil
            $0.settings = SettingsFeature.State(user: nil)
        }
    }
    
    @Test
    func 프로필플로우에서_로그인버튼_탭시_profileFlow는_닫히고_loginProviders가_열린다() async {
        let store = TestStore(
            initialState: MainFeature.State(
                profileFlow: ProfileFlowFeature.State()
            ),
            reducer: { MainFeature() }
        )
        
        await store.send(.profileFlow(.presented(.loginButtonTapped))) {
            $0.profileFlow = nil
            $0.loginProviders = LoginProvidersFeature.State()
        }
    }
    
    @Test
    func 프로필플로우에서_취소버튼_탭시_profileFlow만_닫힌다() async {
        let store = TestStore(
            initialState: MainFeature.State(
                profileFlow: ProfileFlowFeature.State()
            ),
            reducer: { MainFeature() }
        )
        
        await store.send(.profileFlow(.presented(.cancelButtonTapped))) {
            $0.profileFlow = nil
        }
    }
    
    // MARK: - 로그인 플로우
    
    @Test
    func 로그인_성공시_currentUser와_settings가_세팅되고_loginProviders가_닫힌다() async {
        let user = makeUser()
        
        let store = TestStore(
            initialState: MainFeature.State(
                loginProviders: LoginProvidersFeature.State(),
                currentUser: nil
            ),
            reducer: { MainFeature() }
        )
    }
}
