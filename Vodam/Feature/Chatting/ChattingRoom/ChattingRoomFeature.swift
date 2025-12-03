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
    @Dependency(\.firebaseClient) var firebaseClient
    
    nonisolated private let logger = Logger(subsystem: "ChattingRoomFeature", category: "Domain")
    
    // MARK: - State
    @ObservableState
    struct State: Equatable {
        var messageText: String = ""
        var messages: [Message] = []
        var isAITyping: Bool = false
        
        var ownerId: String
        var roomId:String
        var title:String
        
        @Presents var alert: AlertState<Action.Alert>?
        
        // 채팅방 고유ID & API client_id
        init (ownerId: String, roomId: String, title: String){
            self.ownerId = ownerId
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
        
        case deleteButtonTapped
        
        case alert(PresentationAction<Alert>)
        case delegate(DelegateAction)
        
        enum Alert: Equatable {
            case confirmExit
        }
        
        enum DelegateAction: Equatable {
            case didDeleteRoom
        }
        
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
                return .run { [ownerId = state.ownerId, roomId = state.roomId] send in
                    do {
                        let snapshot = try await db.collection("users")
                            .document(ownerId)
                            .collection("chats")
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
                    
                    return .run{[ownerId = state.ownerId, roomId = state.roomId, dummyMessage] _ in
                        let db = Firestore.firestore()
                        let messageData: [String: Any] = [
                            "content": dummyMessage.content,
                            "isFromUser": false as Bool,
                            "timestamp": dummyMessage.timestamp
                        ]
                        do{
                            try await db.collection("users")
                                .document(ownerId)
                                .collection("chats")
                                .document(roomId)
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
                print("💬 [ChattingRoom] sendMessage tapped. current text = '\(state.messageText)'")
                let trimmed = state.messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    print("💬 [ChattingRoom] trimmed is empty, ignoring")
                    return .none
                }
                
                let userMessage = Message(
                    content: state.messageText,
                    isFromUser: true
                )
                state.messages.append(userMessage)
                state.messageText = ""
                
                state.isAITyping = true
                
                return .run { [ownerId = state.ownerId, roomId = state.roomId, title = state.title, userMessage] send in
                    // 유저 메세지 저장
                    let db = Firestore.firestore()
                    
                    Task {
                        do {
                            let messageData : [String: Any] = [
                                "content" : userMessage.content,
                                "isFromUser": true,
                                "timestamp": userMessage.timestamp
                            ]
                            
                            
                            _ = try await db.collection("users")
                                .document(ownerId)
                                .collection("chats")
                                .document(roomId)
                                .collection("messages")
                                .addDocument(data: messageData)
                            
                            let base = userMessage.content
                                .replacingOccurrences(of: "\n", with: " ")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            let short: String
                            if base.count > 25 {
                                short = String(base.prefix(25)) + "..."
                            } else {
                                short = base
                            }
                            
                            try await db.collection("users")
                                .document(ownerId)
                                .collection("chatRooms")
                                .document(roomId)
                                .updateData([
                                    "title": title,
                                    "content": short,
                                    "recentEditedDate": FieldValue.serverTimestamp()
                                ])
                            
                        } catch {
                            logger.error("유저메세지 저장 실패")
                        }
                    }
                    
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
                return .run{ [ownerId = state.ownerId, roomId = state.roomId, title = state.title, aIMessage] _ in
                    let db = Firestore.firestore()
                    
                    let messageData: [String: Any] = [
                        "content": aIMessage.content,
                        "isFromUser": false,
                        "timestamp": aIMessage.timestamp
                    ]
                    
                    do {
                        _ = try? await db.collection("users")
                            .document(ownerId)
                            .collection("chats")
                            .document(roomId)
                            .collection("messages")
                            .addDocument(data: messageData)
                        
                        let base = aIMessage.content
                            .replacingOccurrences(of: "\n", with: " ")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        let short: String
                        if base.count > 25 {
                            short = String(base.prefix(25)) + "..."
                        } else {
                            short = base
                        }
                        
                        try await db.collection("users")
                            .document(ownerId)
                            .collection("chatRooms")
                            .document(roomId)
                            .updateData([
                                "title": title,
                                "content": short,
                                "recentEditedDate": FieldValue.serverTimestamp()
                            ])
                    } catch {
                        logger.error("AI 메세지 저장 실패: \(error.localizedDescription)")
                    }
                }
                
            case .setAITyping(let isTyping):
                state.isAITyping = isTyping
                return .none
                
            case .deleteButtonTapped:
                state.alert = AlertState {
                    TextState("채팅 나가기")
                } actions: {
                    ButtonState(
                        role: .destructive,
                        action: .confirmExit
                    ) {
                        TextState("예")
                    }
                    ButtonState(role: .cancel) {
                        TextState("아니오")
                    }
                } message: {
                    TextState("나가겠습니까?")
                }
                return .none
                
            case .alert(.presented(.confirmExit)):
                let ownerId = state.ownerId
                let roomId = state.roomId
                
                state.alert = nil
                
                return .run { [firebaseClient] send in
                    do {
                        try await firebaseClient.deleteChatRoom(ownerId, roomId)
                        await send(.delegate(.didDeleteRoom))
                    } catch {
                        logger.error("채팅방 삭제 실패: \(error.localizedDescription)")
                    }
                }
                
            case .alert:
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}
