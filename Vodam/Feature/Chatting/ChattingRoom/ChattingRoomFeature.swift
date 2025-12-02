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
        var projectName: String
        
            // 채팅방 고유ID & API client_id
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
                            
                            logger.debug("📦 총 문서 개수: \(snapshot.documents.count)")
                            
                            let messages = snapshot.documents.compactMap { doc -> Message? in
                                print("📄 문서 ID: \(doc.documentID)")
                                print("📄 문서 데이터: \(doc.data())")
                                
                                do {
                                    var message = try doc.data(as: Message.self)
                                    message.id = doc.documentID
                                    print("✅ 디코딩 성공: \(message.content)")
                                    return message
                                } catch {
                                    print("❌ 디코딩 실패: \(error)")
                                    print("❌ 실패한 데이터: \(doc.data())")
                                    return nil
                                }
                            }
                            
                            print("🎯 성공적으로 로드된 메시지: \(messages.count)개")
                            await send(.loadMessages(messages))
                            
                        } catch {
                            logger.error("Failed to load messages: \(error.localizedDescription)")
                            print("🔥 Firebase 로드 에러: \(error)")
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
                        let db = Firestore.firestore()
                        
                        do {
                            let messageData: [String: Any] = [
                                "content" : userMessage.content,
                                "isFromUser": true as Bool,
                                "timestamp":Date()
                                ]
                            
                            _ = try await db.collection("chats")
                                .document(projectName)
                                .collection("messages")
                                .addDocument(data: messageData)
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
                    return .run{ [projectName = state.projectName] _ in
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
