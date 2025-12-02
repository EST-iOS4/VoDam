//
//  ChattingListFeature.swift
//  Vodam
//
//  Created by 이건준 on 11/20/25.
//

import ComposableArchitecture
import Foundation
import OSLog

private let chattingLogger = Logger(subsystem: "Vodam", category: "ChattingList")

@Reducer
struct ChattingListFeature {
    @Dependency(\.firebaseClient) var firebaseClient
    
    
    @ObservableState
    struct State: Equatable {
        var chattingList: [ChattingInfo]
    }
    
    enum Action: Equatable {
        case chattingTapped(ChattingInfo)
        case onAppear
        case updateList([ChattingInfo])
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    await chattingLogger.debug("리스트 감시 시작")
                    for await rooms in await firebaseClient.listenToChatRooms() {
                        await chattingLogger.debug("데이터 도착!")
                        await send(.updateList(rooms))
                    }
                }
                
            case .chattingTapped(let chattingInfo):
                print("선택한 채팅방 정보: \(chattingInfo)")
                return .none
                
            case .updateList(let info):
                state.chattingList = info
                return .none
            }
        }
    }
}

