//
//  SettingView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI

struct SettingView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        let user = store.user

        VStack(spacing: 24) {
            //상단 프로필
            VStack(spacing: 8) {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Text(String(user.name.prefix(1)))
                            .font(.title)
                            .foregroundStyle(.purple)
                    )

                Text(user.name)
                    .font(.headline)

                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(providerText(user.provider))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            Divider()
                .padding(.horizontal)

            //버튼 섹션
            VStack(spacing: 12) {
                Button {
                    store.send(.logoutTapped)
                } label: {
                    Text("로그아웃")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                Button {
                    store.send(.deleteAccountTapped)
                } label: {
                    Text("계정 삭제")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
    }
}
private func providerText(_ provider: AuthProvider) -> String {
    switch provider {
    case .apple: return "Apple로 로그인"
    case .google: return "google로 로그인"
    case .kakao: return "kakao로 로그인"
    }
}
