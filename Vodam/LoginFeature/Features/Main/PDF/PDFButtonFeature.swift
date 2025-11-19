//
//  PDFFeature.swift
//  VoDam
//
//  Created by 강지원 on 11/19/25.
//

import ComposableArchitecture

@Reducer
struct PDFButtonFeature {

    @ObservableState
    struct State: Equatable {
        var title: String = "PDF 가져오기"
    }

    enum Action: Equatable {
        case tapped
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .tapped:
                print("📄 PDF Button tapped")
                return .none
            }
        }
    }
}
