//
//  VoDam.swift
//  Vodam
//
//  Created by 김민우 on 11/17/25.
//
import ComposableArchitecture
import Foundation


// MARK: Object
@Reducer
struct VoDam {
    // MARK: state
    @ObservableState
    struct State {
        
    }
    
    
    // MARK: action
    enum Action {
        
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            return .none
        }
    }
}



