//
//  ProfileFlowView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//


import SwiftUI
import ComposableArchitecture

struct ProfileFlowView: View {
    let store: StoreOf<ProfileFlowFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 0) {
                // 상단 제목
//                HStack {
//                    Spacer()
//                    Text("설정")
//                        .font(.headline)
//                    Spacer()
//                }
//                .padding(.top, 12)
//                .padding(.horizontal, 16)
//                
//                Divider()
//                    .padding(.top, 8)
//                
                Spacer()
                
                VStack(spacing: 16) {
                    Text("""
                   로그인하면 아래 기능을 사용할 수 있어요 👇
                
                   - 녹음 시간 / 횟수 제한 해제 (3회 -> 무제한)
                   - PDF / 파일 / YouTube
                   - 스크립트 및 요약 결과 Blur 제거 
                """)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    
                    Button {
                        viewStore.send(.loginButtonTapped)
                    } label: {
                        Text("로그인 하러 가기")
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                }
                Spacer()
            }
            .padding(.bottom, 24)
        }
    }
}
