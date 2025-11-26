//
//  AISummaryView.swift
//  Vodam
//
//  Created by 서정원 on 11/20/25.
//

import SwiftUI
import ComposableArchitecture

struct AISummaryView: View {
    let store: StoreOf<AISummaryFeature>

    var body: some View {
        Text(store.summary)
            .font(.title2)
            .padding()
    }
}
