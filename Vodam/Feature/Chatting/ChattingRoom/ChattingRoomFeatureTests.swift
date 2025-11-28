//
//  ChattingRoomFeatureTests.swift
//  VodamTests
//
//  Created by 이건준 on 11/26/25.
//

import Testing
import ComposableArchitecture
@testable import Vodam

@MainActor
@Suite
struct ChattingRoomFeatureTests {

    // MARK: - onAppear

    @Test
    func onAppear시_처음_들어오면_웰컴_메시지가_추가된다() async {
        let store = TestStore(
            initialState: ChattingRoomFeature.State(),
            reducer: { ChattingRoomFeature() }
        )

        await store.send(.onAppear) {
            $0.messages = [
                Message(
                    content: "안녕하세요! 오늘 \( $0.projectName )에 대해 무엇을 도와드릴까요?",
                    isFromUser: false
                )
            ]
        }
    }

    @Test
    func onAppear시_이미_메시지가_있으면_웰컴_메시지를_중복해서_추가하지_않는다() async {
        let existing = Message(
            content: "기존 메시지",
            isFromUser: false
        )

        let store = TestStore(
            initialState: ChattingRoomFeature.State(
                messageText: "",
                messages: [existing],
                isAITyping: false,
                projectName: "Vodam"
            ),
            reducer: { ChattingRoomFeature() }
        )

        await store.send(.onAppear) {
            $0.messages = [existing]
        }
    }

    // MARK: - sendMessage → 유저 메시지 + AI 응답 플로우

    @Test
    func sendMessage시_유저_메시지가_추가되고_입력창이_비워진다() async {
        let initialState = ChattingRoomFeature.State(
            messageText: "안녕하세요",
            messages: [],
            isAITyping: false,
            projectName: "Vodam"
        )

        let store = TestStore(
            initialState: initialState,
            reducer: { ChattingRoomFeature() }
        )

        await store.send(.sendMessage) {
            $0.messages = [
                Message(
                    content: "안녕하세요",
                    isFromUser: true
                )
            ]
            $0.messageText = ""
        }
    }

    @Test
    func sendMessage시_AI_타이핑플로우와_응답이_순서대로_진행된다() async {
        let initialState = ChattingRoomFeature.State(
            messageText: "안녕하세요",
            messages: [],
            isAITyping: false,
            projectName: "Vodam"
        )

        let store = TestStore(
            initialState: initialState,
            reducer: { ChattingRoomFeature() }
        )

        await store.send(.sendMessage) {
            $0.messages = [
                Message(
                    content: "안녕하세요",
                    isFromUser: true
                )
            ]
            $0.messageText = ""
        }

        await store.receive(\.setAITyping) {
            $0.isAITyping = true
        }

        await store.receive(\.aIResponse) {
            $0.messages.append(
                Message(
                    content: "안녕하세요! 오늘 Vodam에 대해 궁금하신 점이 있나요?",
                    isFromUser: false
                )
            )
        }
        
        await store.receive(\.setAITyping) {
            $0.isAITyping = false
        }
    }

    // MARK: - aIResponse 단독 테스트

    @Test
    func aIResponse_액션이_들어오면_AI_메시지가_추가된다() async {
        let store = TestStore(
            initialState: ChattingRoomFeature.State(
                messageText: "",
                messages: [],
                isAITyping: false,
                projectName: "Vodam"
            ),
            reducer: { ChattingRoomFeature() }
        )

        await store.send(.aIResponse("테스트 응답입니다")) {
            $0.messages = [
                Message(
                    content: "테스트 응답입니다",
                    isFromUser: false
                )
            ]
        }
    }

    // MARK: - setAITyping 테스트

    @Test
    func setAITyping_액션으로_AI_타이핑_상태를_변경할_수_있다() async {
        let store = TestStore(
            initialState: ChattingRoomFeature.State(
                messageText: "",
                messages: [],
                isAITyping: false,
                projectName: "Vodam"
            ),
            reducer: { ChattingRoomFeature() }
        )

        await store.send(.setAITyping(true)) {
            $0.isAITyping = true
        }

        await store.send(.setAITyping(false)) {
            $0.isAITyping = false
        }
    }
}
