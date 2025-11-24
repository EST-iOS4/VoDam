//
//  SettingView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import PhotosUI
import SwiftUI
import UIKit

struct SettingView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @State private var selectedItem: PhotosPickerItem?

    private var user: User? {
        store.user
    }

    var body: some View {
        WithPerceptionTracking {
            List {
                profileSection
                userInfoSection
                accountSection
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .alert($store.scope(state: \.alert, action: \.alert))
            .onChange(of: selectedItem) { newItem in
                store.send(.photoPickerItemChanged(newItem))
            }
        }
    }

    @ViewBuilder
    private var profileSection: some View {
        Section {
            HStack {
                Spacer()

                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    ProfileImageView(
                        user: user,
                        size: 80,
                        cornerRadius: 24,
                        showEditButton: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(user == nil)

                Spacer()
            }
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var userInfoSection: some View {
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
    }

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if let user = user {
                Button {
                    store.send(.logoutTapped)
                } label: {
                    HStack {
                        Image(
                            systemName: "rectangle.portrait.and.arrow.right"
                        )
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
}

private func providerText(_ provider: AuthProvider) -> String {
    switch provider {
    case .apple: return "Apple"
    case .google: return "google"
    case .kakao: return "Kakao"
    }
}
