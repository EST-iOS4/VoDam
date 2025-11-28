//
//  LoginProvidersView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import AuthenticationServices
import ComposableArchitecture
import SwiftUI

struct LoginProvidersView: View {
    let store: StoreOf<LoginProvidersFeature>
    @Environment(\.colorScheme) var colorScheme

    private let buttonHeight: CGFloat = 52
    private let cornerRadius: CGFloat = 12
    private let horizontalPadding: CGFloat = 24

    var body: some View {
        VStack(spacing: 32) {
            Text("Vodam")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                Button {
                    store.send(.providerTapped(.apple))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .imageScale(.large)

                        Text("Sign in with Apple")
                            .font(.system(size: 19, weight: .medium))
                    }
                    .frame(height: buttonHeight)
                    .frame(maxWidth: .infinity)
                }
                .background(colorScheme == .dark ? Color.white : Color.black)
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                Button {
                    store.send(.providerTapped(.google))
                } label: {
                    HStack(spacing: 8) {
                        Image("google_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)

                        Text("Sign in with Google")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(.black)

                    }
                    .padding(.horizontal, 18)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: buttonHeight,
                        maxHeight: buttonHeight,

                    )
                }
                .buttonStyle(.plain)
                .frame(height: buttonHeight)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            Color(
                                red: 0xDA / 255,
                                green: 0xDC / 255,
                                blue: 0xE0 / 255
                            ),
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                Button {
                    store.send(.providerTapped(.kakao))
                } label: {
                    HStack(spacing: 8) {
                        Image("kakao_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)

                        Text("Sign in with Kakao")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.85))

                    }
                    .padding(.horizontal, 18)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: buttonHeight,
                        maxHeight: buttonHeight,
                    )
                }
                .buttonStyle(.plain)
                .frame(height: buttonHeight)
                .frame(maxWidth: .infinity)
                .background(
                    Color(
                        red: 0xFE / 255,
                        green: 0xE5 / 255,
                        blue: 0x00 / 255
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
            .padding(.horizontal, horizontalPadding)
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .navigationTitle("로그인")
        .navigationBarTitleDisplayMode(.inline)
    }
}
