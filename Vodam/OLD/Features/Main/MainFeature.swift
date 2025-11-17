//
//  MainFeature.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//
import ComposableArchitecture


// MARK: Object
@Reducer
struct MainFeature {
    // MARK: state
    @ObservableState
    struct State {
        @Presents var destination: Destination.State?
    }
    
    @Reducer
    enum Destination {
        case profile(ProfileFlowFeature)
        case loginProvider(LoginProvidersFeature)
    }
    
    
    // MARK: action
    enum Action {
        case destionation(PresentationAction<Destination.Action>)
        case goToProfile
        case goToLoginProviders
        
        case dismissProfileSheet
    }
    
    var body: some Reducer<State, Action> {
        
        Reduce { state, action in
            switch action {
            case .goToProfile:
                state.destination = .profile(.init())
                return .none
                
            case .goToLoginProviders:
                state.destination = .loginProvider(.init())
                return .none
                
            case .destionation(.presented(.profile(.loginButtonTapped))):
                state.destination = nil
                state.destination = .loginProvider(.init())
                return .none
            default:
                print("Action이 호출되었습니다.")
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destionation)
    }
}
