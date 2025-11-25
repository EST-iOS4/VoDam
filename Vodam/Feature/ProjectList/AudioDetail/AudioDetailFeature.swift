//
//  AudioDetailFeature.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import ComposableArchitecture

// TODO: 실제 프로젝트 상세 화면 Feature로 교체해야 합니다.
@Reducer
struct AudioDetailFeature {
    @ObservableState
    struct State: Equatable {
        let project: Project
        var selectedTab: Tab

        var script: ScriptFeature.State
        var aiSummary: AISummaryFeature.State
        
        init(project: Project) {
            self.project = project
            self.selectedTab = .aiSummary
            self.script = ScriptFeature.State()
            self.aiSummary = AISummaryFeature.State()
        }
    }
    
    enum Action: BindableAction {
        case script(ScriptFeature.Action)
        case aiSummary(AISummaryFeature.Action)
        
        case binding(BindingAction<State>)
    }
    
    var body: some Reducer<State, Action> {
        BindingReducer()

        Scope(state: \.script, action: \.script) {
            ScriptFeature()
        }
        
        Scope(state: \.aiSummary, action: \.aiSummary) {
            AISummaryFeature()
        }
    }
}
