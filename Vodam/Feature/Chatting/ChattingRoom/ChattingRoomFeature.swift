//
//  ChattingRoomFeature.swift
//  Vodam
//
//  Created by 이건준 on 11/24/25.
//

import SwiftData
import Foundation
import ComposableArchitecture

@Reducer
struct ChattingRoomFeature {
        // MARK: - State
    @ObservableState
    struct State: Equatable {
        var messageText: String = ""
        var messages: [Message] = []
        var isAITyping: Bool = false
        var projectName: String = "Vodam"
    }
    
        // MARK: - Action
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case sendMessage
        case aIResponse(String)
        case setAITyping(Bool)
        case backButtonTapped
        case settingButtonTapped
    }
    
        // MARK: - Reducer
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
                case .binding:
                    return .none
                    
                case .onAppear:
                    if state.messages.isEmpty {
                        let dummyMessage = Message(
                            content: "안녕하세요! 오늘 \(state.projectName)에 대해 무엇을 도와드릴까요?",
                            isFromUser: false,
                            timestamp: Date().addingTimeInterval(-300)
                        )
                        state.messages.append(dummyMessage)
                    }
                    return .none
                    
                case .sendMessage:
                    let userMessage = Message(
                        content: state.messageText,
                        isFromUser: true
                    )
                    state.messages.append(userMessage)
                    state.messageText = ""
                    
                    return .run { [projectName = state.projectName] send in
                        await send(.setAITyping(true))
                        try await Task.sleep(for: .seconds(2))
                        await send(.aIResponse("안녕하세요! 오늘 \(projectName)에 대해 궁금하신 점이 있나요?"))
                        await send(.setAITyping(false))
                    }
                    
                case .aIResponse(let content):
                    let aIMessage = Message(
                        content: content,
                        isFromUser: false
                    )
                    state.messages.append(aIMessage)
                    return .none
                    
                case .setAITyping(let isTyping):
                    state.isAITyping = isTyping
                    return .none
                    
                case .backButtonTapped:
                    return .none
                    
                case .settingButtonTapped:
                    return .none
            }
        }
    }
}
