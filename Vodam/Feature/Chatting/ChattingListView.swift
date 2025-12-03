//
//  ChattingListView.swift
//  Vodam
//
//  Created by 이건준 on 11/19/25.
//

import ComposableArchitecture
import SwiftUI

struct ChattingListView: View {
    @Bindable var store: StoreOf<ChattingListFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            List(store.chattingList) { chattingInfo in
                Button {
                    store.send(.chattingTapped(chattingInfo))
                } label: {
                    ChattingItemView(chattingInfo: chattingInfo)
                        .listRowSeparator(.hidden)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .padding(.horizontal, 10)
            .onAppear {
                print("뷰 호출됨!")
                store.send(.onAppear)
            }
        } destination: { store in
            ChattingRoomView(store: store)
        }
    }
}
