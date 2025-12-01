    //
    //  ChattingListFeature.swift
    //  Vodam
    //
    //  Created by 이건준 on 11/20/25.
    //

import ComposableArchitecture
import Foundation

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
                        for await rooms in firebaseClient.listenToChatRooms() {
                            await send(.updateList(rooms))
                        }
                    }
                    
                case .chattingTapped(let chattingInfo):
                    print("선택한 채팅방 정보: \(chattingInfo)")
                    return .none
                    
                case .updateList(let info):
                    state.chattingList = info
                    return .none
                    
                case .onAppear:
                    return .run { send in
                        print("📡 리스트 감시 시작...") // 1번 로그
                        for await rooms in firebaseClient.listenToChatRooms() {
                            print("📦 데이터 도착! 개수: \(rooms.count)") // 2번 로그
                            await send(.updateList(rooms))
                        }
                    }
            }
        }
    }
}
