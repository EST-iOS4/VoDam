//
//  LoginProvidersView.swift
//  Vodam
//
//  Created by 송영민 on 11/17/25.
//

import SwiftUI
import ComposableArchitecture

struct LoginProvidersView: View {
    let store: StoreOf<LoginProvidersFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 24) {
                Text("Vodam")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button {
                        viewStore.send(.appleTapped)
                    } label: {
                        Text("Sign in with Apple")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        viewStore.send(.googleTapped)
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
                        viewStore.send(.kakaoTapped)
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
}
