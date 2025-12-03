//
//  ChattingListFeature.swift
//  Vodam
//
//  Created by 이건준 on 11/20/25.
//

import ComposableArchitecture
import Foundation
import OSLog
import SwiftUI

private let chattingLogger = Logger(subsystem: "Vodam", category: "ChattingList")

@Reducer
struct ChattingListFeature {
    @Dependency(\.firebaseClient) var firebaseClient
    
    @ObservableState
    struct State: Equatable {
        var chattingList: [ChattingInfo] = []
        var path = StackState<ChattingRoomFeature.State>()
        
        var currentUser: User? = nil
    }
    
    enum Action {
        case chattingTapped(ChattingInfo)
        case onAppear
        case updateList([ChattingInfo])
        case delete(IndexSet)
        case path(StackAction<ChattingRoomFeature.State, ChattingRoomFeature.Action>)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard let ownerId = state.currentUser?.ownerId else {
                    chattingLogger.debug("로그인 유저 없음 - 채팅 목록 비움")
                    state.chattingList = []
                    return .none
                }
                
                return .run { send in
                    await chattingLogger.debug("리스트 감시 시작 ownerId=\(ownerId)")
                    for await rooms in await firebaseClient.listenToChatRooms(ownerId) {
                        await chattingLogger.debug("데이터 도착! rooms=\(rooms.count)")
                        await send(.updateList(rooms))
                    }
                }
                
            case .chattingTapped(let chattingInfo):
                print("선택한 채팅방 정보: \(chattingInfo)")
                
                guard let ownerId = state.currentUser?.ownerId else {
                    chattingLogger.error("로그인 유저 없음 - 채팅방 진입 불가")
                    return .none
                }
                
                let roomState = ChattingRoomFeature.State(
                    ownerId: ownerId,
                    roomId: chattingInfo.id,
                    title: chattingInfo.title
                )
                state.path.append(roomState)
                return .none
                
            case .updateList(let info):
                state.chattingList = info
                return .none
                
            case .delete(let indexSet):
                guard let ownerId = state.currentUser?.ownerId else {
                    chattingLogger.error("로그인 유저 없음 (삭제 불가)")
                    return .none
                }
                
                let targets = indexSet.compactMap { index -> ChattingInfo? in
                    guard state.chattingList.indices.contains(index) else {
                        return nil
                    }
                    return state.chattingList[index]
                }
                
                state.chattingList.remove(atOffsets: indexSet)
                
                return .run { [firebaseClient] _ in
                    for info in targets {
                        do {
                            try await firebaseClient.deleteChatRoom(ownerId, info.id)
                            await chattingLogger.debug("채팅방 삭제 완료: \(info.id)")
                        } catch {
                            await chattingLogger.debug("채팅방 삭제 실패 : \(error.localizedDescription)")
                        }
                    }
                }
                
            case .path(.element(id: _, action: .delegate(.didDeleteRoom))):
                state.path = .init()
                return .none
                
            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            ChattingRoomFeature()
        }
    }
}
