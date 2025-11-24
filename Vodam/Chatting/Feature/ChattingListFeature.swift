//
//  ChattingListFeature.swift
//  Vodam
//
//  Created by 이건준 on 11/20/25.
//

import ComposableArchitecture

@Reducer
struct ChattingListFeature {
    enum Action: Equatable {
        case chattingTapped(ChattingInfo)
    }

    @ObservableState
    struct State: Equatable {
        var chattingList: [ChattingInfo]
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .chattingTapped(let chattingInfo):
                print("선택한 채팅방 정보: \(chattingInfo)")
                return .none
            }
        }
    }
}
