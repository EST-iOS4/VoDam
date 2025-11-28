//
//  ChattingListFeatureTests.swift
//  VodamTests
//
//  Created by 이건준 on 11/26/25.
//

internal import Foundation
import Testing
import ComposableArchitecture
@testable import Vodam

@MainActor
@Suite
struct ChattingListFeatureTests {

    @Test
    func 채팅_탭_액션이_와도_state는_변하지_않는다() async {
        let chattingList = [
            ChattingInfo(
                id: "1",
                title: "프로젝트 1",
                content: "대화 내용...",
                recentEditedDate: Date()
            ),
            ChattingInfo(
                id: "2",
                title: "프로젝트 2",
                content: "다른 대화 내용...",
                recentEditedDate: Date()
            )
        ]

        let store = TestStore(
            initialState: ChattingListFeature.State(
                chattingList: chattingList
            ),
            reducer: { ChattingListFeature() }
        )

        let first = chattingList[0]
        await store.send(.chattingTapped(first))
    }
}

