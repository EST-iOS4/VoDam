//
//  MainFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture

@Reducer
struct MainFeature {
    
    @ObservableState
    struct State: Equatable {}
    
    enum Action: Equatable {}
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
                .none
        }
    }
}
