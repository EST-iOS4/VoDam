//
//  ProfileFlowView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct ProfileFlowView: View {
    let store: StoreOf<ProfileFlowFeature>
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            Text(
                """
                   로그인하면 아래 기능을 사용할 수 있어요 👇
                
                   - 녹음 시간 / 횟수 제한 해제 (3회 -> 무제한)
                   - PDF / 녹음 파일 가져오기
                   - Ai 채팅
                
                """
            )
            .font(AppFont.pretendardRegular(size: 15))
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            
            Button {
                store.send(.loginButtonTapped)
            } label: {
                Text("로그인")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(14)
            }
            
            Button {
                store.send(.guestButtonTapped)
            } label: {
                Text("비회원으로 사용")
                    .foregroundStyle(.primary)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(.systemGray4), lineWidth: 1.5)
                    )
            }
        }
        .padding(.top, 40)
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
