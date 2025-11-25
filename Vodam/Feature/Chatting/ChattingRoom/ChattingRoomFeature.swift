    //
    //  ChatFeature.swift
    //  Vodam
    //
    //  Created by EunYoung Wang on 11/24/25.
    //

import FirebaseFirestore
import Foundation
import ComposableArchitecture

@Reducer
struct ChatFeature {
        // MARK: - State
    @ObservableState
    struct State: Equatable {
        var messageText: String = ""
        var messages: [Message] = []
        var isAITyping: Bool = false
        var projectName: String
        
        init (projectName: String){
            self.projectName = projectName
        }
    }
    
        // MARK: - Action
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case sendMessage
        case loadMessages([Message])
        case aIResponse(String)
        case setAITyping(Bool)
    }
    
    let db = Firestore.firestore()
    
        // MARK: - Reducer
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
                case .binding:
                    return .none
                    
                case .onAppear:
                    return .run { [projectName = state.projectName] send in
                        do {
                            let snapshot = try await db.collection("chats")
                                .document(projectName)
                                .collection("messages")
                                .order(by: "timestamp", descending: false)
                                .getDocuments()
                            
                            let messages = snapshot.documents.compactMap { doc -> Message? in
                                try? doc.data(as: Message.self)
                            }
                            
                            await send(.loadMessages(messages))
                            
                        } catch {
                            print("Failed to load messages: \(error)")
                            await send(.loadMessages([]))
                        }
                    }
                    
                case .loadMessages(let loadedMessages):
                    if loadedMessages.isEmpty{
                        let dummyMessage = Message(
                            content: "안녕하세요! 오늘 \(state.projectName)에 대해 무엇을 도와드릴까요?",
                            isFromUser: false,
                            timestamp: Date().addingTimeInterval(-300)
                        )
                        state.messages = [dummyMessage]
                    } else{
                        state.messages = loadedMessages
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
                            // 유저 메세지 저장
                        do {
                            try await db.collection("chats")
                                .document(projectName)
                                .collection("messages")
                                .addDocument(from: userMessage)
                        } catch {
                            print("Failed to save user message: \(error)")
                        }
                        
                        await send(.setAITyping(true))
                            // API
                        do {
                            let reply = try await AlanClient.shared.sendQuestion(
                                content: userMessage.content,
                                clientID: projectName
                            )
                            await send(.aIResponse(reply))
                        } catch {
                            print("Alan API Error: \(error)")
                            await send(.aIResponse("죄송해요, 지금은 대답하기 어려워요."))
                        }
                        
                        await send(.setAITyping(false))
                    }
                    
                case .aIResponse(let content):
                    let aIMessage = Message(
                        content: content,
                        isFromUser: false
                    )
                    state.messages.append(aIMessage)
                        // AI 메세지 저장
                    return .run{ [projectName = state.projectName] _ in
                        try? await db.collection("chats")
                            .document(projectName)
                            .collection("messages")
                            .addDocument(from: aIMessage)
                    }
                    
                case .setAITyping(let isTyping):
                    state.isAITyping = isTyping
                    return .none
            }
        }
    }
}
