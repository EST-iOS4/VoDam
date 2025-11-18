//
//  RecordingFeature.swift
//  VoDam
//
//  Created by 강지원 on 11/18/25.
//

import ComposableArchitecture

struct RecordingCancelID: Hashable {}

@Reducer
struct RecordingFeature {

    enum Status: Equatable {
        case ready
        case recording
        case paused

        var localizedText: String {
            switch self {
            case .ready: "준비됨"
            case .recording: "녹음 중"
            case .paused: "일시정지"
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        var status: Status = .ready
    }

    enum Action: Equatable {
        case startTapped
        case pauseTapped
        case stopTapped
    }

    var body: some Reducer<State, Action> { // action을 받아 state를 변경
        Reduce { state, action in
            switch action {

            case .startTapped:
                state.status = .recording
                return .none

            case .pauseTapped:
                state.status = .paused
                return .none

            case .stopTapped:
                state.status = .ready
                return .none
            }
        }
    }
}
