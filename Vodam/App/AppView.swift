//
//  AppView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { _ in
            MainView(
                store: store.scope(state: \.main, action: \.main)
            )
        }
    }
}
