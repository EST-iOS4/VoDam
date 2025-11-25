//
//  KakaoAuthClient.swift
//  Vodam
//
//  Created by 송영민 on 11/25/25.
//

import Dependencies
import Foundation

struct KakaoAuthClient {
    var login: @Sendable () async throws -> User

    var logout: @Sendable () async throws -> Void

    var deleteAccount: @Sendable () async throws -> Void
}

extension KakaoAuthClient: DependencyKey {
    static var liveValue: KakaoAuthClient {
        .init(
            login: {
                try await AuthService.loginWithKaKao()
            },
            logout: {
                try await AuthService.logout()
            },
            deleteAccount: {
                try await AuthService.deleteAccount()
            }
        )
    }

    static var testValue: KakaoAuthClient {
        .init(
            login: {
                User(
                    id: "test-kakao-id",
                    name: "Test Kakao User",
                    email: "test@kakao.com",
                    provider: .kakao,
                    profileImageURL: nil,
                    localProfileImageData: nil
                )
            },
            logout: {},
            deleteAccount: {}
        )
    }

//    static var previewValue: KakaoAuthClient {
//        .testValue
//    }
}

extension DependencyValues {
    var kakaoAuthClient: KakaoAuthClient {
        get {
            self[KakaoAuthClient.self]
        }
        set {
            self[KakaoAuthClient.self] = newValue
        }
    }
}
