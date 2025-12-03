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
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if store.chattingList.isEmpty {
                    emptyView
                } else {
                    ChattingListView
                }
            }
            .onAppear {
                print("뷰 호출됨!")
                store.send(.onAppear)
            }
            
        } destination: { store in
            ChattingRoomView(store: store)
        }
    }
    
    private var ChattingListView: some View {
        List {
            ForEach(store.chattingList) { chattingInfo in
                Button {
                    store.send(.chattingTapped(chattingInfo))
                } label: {
                    ChattingItemView(chattingInfo: chattingInfo)
                        .listRowSeparator(.hidden)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.6), lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                store.send(.delete(indexSet))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 10)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Text("저장된 채팅이 없습니다.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

