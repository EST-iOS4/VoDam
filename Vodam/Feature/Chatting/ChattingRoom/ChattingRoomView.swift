    //
    //  ChattingRoomView.swift
    //  Vodam
    //
    //  Created by EunYoung Wang on 11/24/25.
    //

import SwiftUI
import ComposableArchitecture

struct ChattingRoomView: View {
    @Bindable var store: StoreOf<ChattingRoomFeature>
        // @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
                // MARK: - 메시지 리스트
            ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(store.messages) { message in
                                        MessageRow(message: message)
                                    }
                                }
                                .padding()
                            }
                            .onChange(of: store.messages) { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation {
                                        proxy.scrollTo(store.messages.last?.id, anchor: .bottom)
                                    }
                                }
                            }
                            .onAppear {
                                store.send(.onAppear)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation {
                                        proxy.scrollTo(store.messages.last?.id, anchor: .bottom)
                                    }
                                }
                            }
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
                    Image(systemName: "arrow.up.circle")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
        .navigationTitle(store.projectName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
    }
}

    // MARK: - 메시지 행
struct MessageRow: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if message.isFromUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(AppColor.mainColor)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    Text(format(message.timestamp))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.trailing, 6)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                    Text(format(message.timestamp))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.leading, 6)
                }
                Spacer()
            }
        }
    }
    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
    
//        // MARK: - Preview
//    #Preview {
//        NavigationStack {
//            ChattingRoomView(
//                store: Store(initialState: ChattingRoomFeature.State(projectName:"프로젝트 채팅 리스트")) {
//                    ChattingRoomFeature()
//                }
//            )
//        }
//    }
//    
