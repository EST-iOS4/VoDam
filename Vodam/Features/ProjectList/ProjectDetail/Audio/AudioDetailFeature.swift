//
//  ProjectDetailFeature.swift
//  Vodam
//
//  Created by 서정원 on 11/18/25.
//

import ComposableArchitecture

// TODO: 실제 프로젝트 상세 화면 Feature로 교체해야 합니다.
@Reducer
struct AudioDetailFeature {
    @ObservableState
    struct State: Equatable {
        let project: Project
    }
    
    enum Action {
        
    }
    
    var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
