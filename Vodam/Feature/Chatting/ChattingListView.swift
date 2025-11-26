//
//  ChattingListView.swift
//  Vodam
//
//  Created by 이건준 on 11/19/25.
//

import ComposableArchitecture
import SwiftUI

struct ChattingListView: View {
    let store: StoreOf<ChattingListFeature>

    var body: some View {
        List(store.chattingList) { chattingInfo in
            Button {
                store.send(.chattingTapped(chattingInfo))
            } label: {
                ChattingItemView(chattingInfo: chattingInfo)
                    .listRowSeparator(.hidden)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .background(Color.white)
        .background(ignoresSafeAreaEdges: .vertical)
        .padding(.horizontal, 10)
    }
}
