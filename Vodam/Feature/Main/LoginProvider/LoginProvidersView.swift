//
//  LoginProvidersView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import ComposableArchitecture
import SwiftUI
import AuthenticationServices

struct LoginProvidersView: View {
   let store: StoreOf<LoginProvidersFeature>
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Vodam")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 40)

            Spacer()

            VStack(spacing: 16) {
                SignInWithAppleButton (
                    .signIn,
                    onRequest: { request in
                    },
                    onCompletion: { result in
                        switch result {
                        case .success:
                            store.send(.providerTapped(.apple))
                            print("Apple 로그인 성공")
                                                        
                        case .failure(let error):
                        print("Apple 로그인 실패: \(error.localizedDescription)")
                
                        }
                    }
                )
                .signInWithAppleButtonStyle(
                    colorScheme == .light ? .black : .white
                )
                .frame(height: 50)
                .cornerRadius(12)
                  
                Button {
                    store.send(.providerTapped(.google))
                } label: {
                    Text("Sign in with Google")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                }

                Button {
                    store.send(.providerTapped(.kakao))
                } label: {
                    Text("Sign in with KaKao")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .navigationTitle("로그인")
        .navigationBarTitleDisplayMode(.inline)
    }
}
