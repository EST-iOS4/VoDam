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

    var body: some View {
        VStack(spacing: 0) {
            // 오른쪽 상단 X 버튼
            HStack {
                Spacer()
                Button {
                    store.send(.cancelButtonTapped)
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .frame(width: 30 , height: 30)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .padding(12)
            }
          Spacer()
            
            VStack(spacing: 16) {
                Text(
                    """
                       로그인하면 아래 기능을 사용할 수 있어요 👇

                       - 녹음 시간 / 횟수 제한 해제 (3회 -> 무제한)
                       - PDF / 파일 / YouTube
                         스크립트 및 요약 결과 Blur 제거 
                    """
                )
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)

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
                .padding(.horizontal, 24)
                
                Button {
                    store.send(.guestButtonTapped)
                    
                } label: {
                    Text("비회원으로 사용")
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
            }
            Spacer()
        }
        .padding(.bottom, 24)
    }
}
