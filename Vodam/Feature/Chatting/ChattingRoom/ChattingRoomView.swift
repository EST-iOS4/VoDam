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
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - 메시지 리스트
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.messages, id: \.uniqueId) { message in
                                MessageRow(message: message)
                                    .id(message.uniqueId)
                            }
                            
                            if store.isAITyping{
                                HStack{
                                    LoadingBubbleView()
                                    Spacer()
                                }
                                .id("ai_typing_bubble")
                            }
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding()
                    }
                    
                    .onChange(of: store.messages) { oldValue, newValue in
                        guard newValue.count > oldValue.count else { return }
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: store.isAITyping){ _, isTyping in
                        guard isTyping else { return }
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
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
                    .onSubmit {
                        store.send(.sendMessage)
                    }
                    
                    Button {
                        store.send(.sendMessage)
                    } label: {
                        Image(systemName: "arrow.up.circle")
                            .font(AppFont.pretendardRegular(size: 28))
                            .foregroundColor(
                                store.messageText.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                ).isEmpty
                                ? .gray
                                : .blue
                            )
                    }
                    .disabled(
                        store.messageText.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle(store.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar{
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.deleteButtonTapped)
                } label: {
                    Image(systemName: "door.right.hand.open")
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
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
                        .font(AppFont.pretendardRegular(size: 14))
                        .foregroundColor(.gray)
                        .padding(.trailing, 6)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    MarkdownTextView(
                        message.content,
                        font: .body,
                        linSpacing: 4
                    )
                    .padding(12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)
                    Text(format(message.timestamp))
                        .font(AppFont.pretendardRegular(size: 14))
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

// MARK: - 메세지 입력 중 애니메이션

struct LoadingBubbleView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(.gray.opacity(0.5))
                        .scaleEffect(isAnimating ? 1.0 : 0.6)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(16)
            .onAppear {
                isAnimating = true
            }
        }
        .padding(.leading, 16)
    }
}
