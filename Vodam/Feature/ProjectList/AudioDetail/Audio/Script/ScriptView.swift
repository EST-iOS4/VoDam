//
//  ScriptView.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture

struct ScriptView: View {
    let store: StoreOf<ScriptFeature>

    var body: some View {
        Text(store.text)
            .font(.title)
            .padding()
    }
}
