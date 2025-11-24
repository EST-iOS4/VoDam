//
//  ChattingListView.swift
//  Vodam
//
//  Created by 이건준 on 11/19/25.
//

import SwiftUI

import ComposableArchitecture

struct ChattingListView: View {
    let store: StoreOf<ChattingListFeature>
    
    var body: some View {
        WithPerceptionTracking {
            List(store.chattingList) { chattingInfo in
                Button {
                    store.send(.chattingTapped(chattingInfo))
                } label: {
                    ChattingView(chattingInfo: chattingInfo)
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
}
