//
//  VodamTests.swift
//  VodamTests
//
//  Created by 이건준 on 11/25/25.
//

import Testing
import ComposableArchitecture
@testable import Vodam

@MainActor
struct AppFeatureTests {

    @Test
    func 초기_탭은_main이어야_한다() async {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )

        #expect(store.state.startTab == .main)
    }

    @Test
    func startTab_액션으로_탭을_list로_변경할_수_있다() async {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )

        await store.send(.startTab(.list)) {
            $0.startTab = .list
        }
    }

    @Test
    func startTab_액션으로_탭을_chat으로_변경할_수_있다() async {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )

        await store.send(.startTab(.chat)) {
            $0.startTab = .chat
        }
    }

    @Test
    func startTab_액션으로_탭을_main으로_변경할_수_있다() async {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )

        await store.send(.startTab(.main)) 
    }
}


