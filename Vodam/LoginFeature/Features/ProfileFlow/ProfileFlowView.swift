//
//  ProfileFlowView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct ProfileFlowView: View {
    let store: StoreOf<ProfileFlowFeature>

    var body: some View {
        LoginInfoView(
            onLoginButtonTapped: {
                store.send(.loginButtonTapped)
            },
            onCancelButtonTapped: {
                store.send(.cancelButtonTapped)
            }
        )
    }
}
