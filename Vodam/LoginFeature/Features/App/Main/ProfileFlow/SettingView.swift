//
//  SettingView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import PhotosUI
import SwiftUI

struct SettingView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        let user = store.user

        List {
            //프로필
            Section {
                HStack {
                    Spacer()

                    Button(action: {
                        //(일단) 로그인 상태만 프로필 이미지 변경 가능하게
                        if user != nil{
                            store.send(.profileImageChage)
                        }
                    }) {
                        ZStack(alignment: .bottomTrailing) {
                            if let url = user?.profileImageURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 80, height: 80)

                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 80, height: 80)
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: 24
                                                )
                                            )

                                    case .failure:
                                        defaultProfileRect()

                                    @unknown default:
                                        defaultProfileRect()
                                    }

                                }
                            } else {
                                defaultProfileRect()
                            }
                            //로그인 일때만 편집 버튼 보여주기
                            if user != nil {
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
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(user == nil)
                    
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
                    Text(user?.name ?? "게스트")
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)

                HStack {
                    Image(systemName: "envelope.circle")
                    Text("이메일")
                    Spacer()
                    if let email = user?.email {
                        Text(email)
                            .foregroundColor(.secondary)
                    } else {
                        Text(user != nil ? "이메일 없음" : "비로그인")
                            .foregroundColor(.secondary)
                    }

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
                if let user = user {
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
                } else {
                    //비로그인
                    Button {
                        store.send(.loginButtonTapped)
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("로그인")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private func defaultProfileRect() -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(red: 0.0, green: 0.5, blue: 1.0))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "person")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            )
    }

}

private func providerText(_ provider: AuthProvider) -> String {
    switch provider {
    case .apple: return "Apple"
    case .google: return "google"
    case .kakao: return "Kakao"
    }
}
