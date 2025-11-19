//
//  FileButtonFeature.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import ComposableArchitecture

@Reducer
struct FileButtonFeature {

    @ObservableState
    struct State: Equatable {
        var title: String = "파일 가져오기"
    }

    enum Action: Equatable {
        case tapped
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .tapped:
                print("📁 File Button tapped")
                return .none
            }
        }
    }
}
