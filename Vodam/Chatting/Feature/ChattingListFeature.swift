//
//  ChattingListFeature.swift
//  Vodam
//
//  Created by 이건준 on 11/20/25.
//

import ComposableArchitecture

@Reducer
struct ChattingListFeature {
    enum Action {
        case chattingTapped(ChattingInfo)
    }
    
    @ObservableState
    struct State {
        var chattingList: [ChattingInfo]
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .chattingTapped(let chattingInfo):
            print("선택한 채팅방 정보: \(chattingInfo)")
        }
        
        return .none
    }
}
