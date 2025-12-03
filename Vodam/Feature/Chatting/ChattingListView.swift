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
            if store.chattingList.isEmpty{
                EmptyView()
                    .onAppear{
                        store.send(.onAppear)
                    }
            } else{
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
            }
        } destination: { store in
            ChattingRoomView(store: store)
        }
    }
}

struct EmptyView: View{
    var body: some View{
        VStack{
            Text("저장된 리스트가 없습니다.")
                .font(AppFont.pretendardBold(size: 16))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
