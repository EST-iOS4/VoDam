    //
    //  ChattingRoomFeature.swift
    //  Vodam
    //
    //  Created by EunYoung Wang on 11/24/25.
    //

import FirebaseFirestore
import Foundation
import ComposableArchitecture
import OSLog

@Reducer
struct ChattingRoomFeature {
    
    nonisolated private let logger = Logger(subsystem: "ChattingRoomFeature", category: "Domain")
    
        // MARK: - State
    @ObservableState
    struct State: Equatable {
        var messageText: String = ""
        var messages: [Message] = []
        var isAITyping: Bool = false
        
        var roomId:String
        var title:String
        
            // 채팅방 고유ID & API client_id
        init (roomId: String, title: String){
            self.roomId = roomId
            self.title = title
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
                    return .run { [roomId = state.roomId] send in
                        do {
                            let snapshot = try await db.collection("chats")
                                .document(roomId)
                                .collection("messages")
                                .order(by: "timestamp", descending: false)
                                .getDocuments()
                            
                            logger.debug("📦 총 문서 개수: \(snapshot.documents.count)")
                            
                            let messages = snapshot.documents.compactMap { doc -> Message? in
                                
                                do {
                                    var message = try doc.data(as: Message.self)
                                    message.id = doc.documentID
                                    return message
                                } catch {
                                    return nil
                                }
                            }
                            
                            await send(.loadMessages(messages))
                            
                        } catch {
                            logger.error("Failed to load messages: \(error.localizedDescription)")
                            await send(.loadMessages([]))
                        }
                    }
                    
                case .loadMessages(let loadedMessages):
                    if loadedMessages.isEmpty{
                        let dummyMessage = Message(
                            content: "안녕하세요! 오늘 \(state.title)에 대해 무엇을 도와드릴까요?",
                            isFromUser: false,
                            timestamp: Date()
                        )
                        state.messages = [dummyMessage]
                        
                        return .run{[projectName = state.projectName] _ in
                            let db = Firestore.firestore()
                            let messageData: [String: Any] = [
                                "content": dummyMessage.content,
                                "isFromUser": false as Bool,
                                "timestamp": Date()
                            ]
                            do{
                                try await db.collection("chats")
                                    .document(projectName)
                                    .collection("messages")
                                    .addDocument(data: messageData)
                                logger.info("환영메세지 저장완료")
                            } catch{
                                logger.error("환영메세지 저장실패: \(error.localizedDescription)")
                            }
                        }
                    } else{
                        state.messages = loadedMessages
                        
                        return .none
                    }
                    
                case .sendMessage:
                    let userMessage = Message(
                        content: state.messageText,
                        isFromUser: true
                    )
                    state.messages.append(userMessage)
                    state.messageText = ""
                    
                    return .run { [roomId = state.roomId] send in
                            // 유저 메세지 저장
                        let db = Firestore.firestore()
                        
                        do {
                            let _: [String: Any] = [
                                "content" : userMessage.content,
                                "isFromUser": true as Bool,
                                "timestamp":Date()
                            ]
                            
                            let roomSnapshout = try await db.collection("chatRooms").document(projectName)
                                .getDocument()
                            if let currentContent = roomSnapshout.data()?["content"] as? String,
                               currentContent == "-" {
                                try await db.collection("chatRooms")
                                    .document(projectName)
                                    .updateData([
                                        "content": userMessage.content,
                                        "recentEditedDate": FieldValue.serverTimestamp()
                                    ])
                                logger.info("첫 질문 저장완료")
                            }
                        }
                        catch {
                            logger.error("유저메세지 저장 실패")
                        }
                        
                        await send(.setAITyping(true))
                            // API
                        do {
                            let question = AlanClient.Question(userMessage.content)
                            let answer = try await AlanClient.shared.question(question)
                            
                            await send(.aIResponse(answer.content))
                        } catch {
                            logger.debug("Alan API Error")
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
                    return .run{ [roomId = state.roomId] _ in
                        let db = Firestore.firestore()
                        
                        let messageData: [String: Any] = [
                            "content": content,
                            "isFromUser": false as Bool,
                            "timestamp": Date()
                        ]
                        
                        _ = try? await db.collection("chats")

                            .document(projectName)
                            .collection("messages")
                            .addDocument(data: messageData)

                    }
                    
                case .setAITyping(let isTyping):
                    state.isAITyping = isTyping
                    return .none
            }
        }
    }
}
