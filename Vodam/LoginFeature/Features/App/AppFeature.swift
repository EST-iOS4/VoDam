//
//  AppFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture

@Reducer // Reducer 선언
struct AppFeature {
    
    @ObservableState // state에 대한 상태 변화 관찰(?)
    struct State: Equatable { // Store가 State 변화를 감지할 때 Equatable 비교 사용
        var main = MainFeature.State() // MainFeature 상태 전달
    }
    
    enum Action: Equatable {
        case main(MainFeature.Action) //MainFeature에서 발생하는 Action
    }
    
    var body: some Reducer<State, Action> { //MainFeature의 State와 Action을 전달
        Scope(state: \.main, action: \.main) {
            MainFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .main:
                return .none
            @unknown default:
                return .none
            }
        }
    }
}
