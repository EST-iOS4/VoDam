//
//  ChattingRoomView.swift
//  Vodam
//
//  Created by 이건준 on 11/24/25.
//

import SwiftUI
import ComposableArchitecture

struct ChattingRoomView: View {
    @Bindable var store: StoreOf<ChattingRoomFeature>
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 메시지 리스트
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.messages) { message in
                        MessageRow(message: message)
                    }
                }
                .padding()
            }
            
            // MARK: - 입력창
            HStack(spacing: 12) {
                TextField(
                    "메시지를 입력하세요",
                    text: $store.messageText
                )
                .textFieldStyle(.roundedBorder)
                
                Button {
                    store.send(.sendMessage)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
        .navigationTitle("채팅")
        .onAppear {
            store.send(.onAppear)
        }
    }
}

// MARK: - 메시지 행
struct MessageRow: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                Text(message.content)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            } else {
                Text(message.content)
                    .padding(12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
                Spacer()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        ChattingRoomView(
            store: Store(initialState: ChattingRoomFeature.State()) {
                ChattingRoomFeature()
            }
        )
    }
}
