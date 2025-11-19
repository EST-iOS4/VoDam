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

        List {
            //프로필
            Section {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        store.send(.profileImageChage)
                    }) {
                        ZStack(alignment: .bottomTrailing) {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color(red: 0.0, green: 0.5, blue: 1.0))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                )
                            
                            Circle()
                                .fill(Color.black)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: "pencil")
                                        .font(.system(size: 25))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)

            //메뉴1
            Section {
                HStack {
                    Image(systemName: "person.circle")
                    Text("이름")
                    Spacer()
                    Text(user.name)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)

                HStack {
                    Image(systemName: "envelope.circle")
                    Text("이메일")
                    Spacer()
                    Text(user.email)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)

                HStack {
                    Image(systemName: "exclamationmark.circle")
                    Text("개인정보처리방침")
                }
                .foregroundColor(.primary)

                HStack {
                    Image(systemName: "questionmark.circle")
                    Text("문의하기")
                }
                .foregroundColor(.primary)
            }

            //메뉴2
            Section {
                Button {
                    store.send(.logoutTapped)
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("로그아웃")
                        Spacer()
                        Text(providerText(user.provider))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .foregroundStyle(.primary)
                
                Button {
                    store.send(.deleteAccountTapped)
                } label: {
                    HStack {
                        Image(systemName: "trash.circle")
                        Text("계정 삭제")
                            .foregroundColor(.red)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func providerText(_ provider: AuthProvider) -> String {
    switch provider {
    case .apple: return "Apple"
    case .google: return "google"
    case .kakao: return "Kakao"
    }
}
