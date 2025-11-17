//
//  ProfileFlowView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//


import SwiftUI
import ComposableArchitecture

struct ProfileFlowView: View {
    let store: StoreOf<ProfileFlowFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            LoginInfoView (
                onLoginButtonTapped: {
                    viewStore.send(.loginButtonTapped)
                },
                onCancelButtonTapped: {
                    viewStore.send(.cancelButtonTapped)
                }
            )
        }
    }
}
