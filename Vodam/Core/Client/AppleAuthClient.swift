//
//  AppleAuthClient.swift
//  Vodam
//
//  Created by 송영민 on 11/26/25.
//

import AuthenticationServices
import Dependencies
import Foundation

struct AppleAuthClient {
    var login: @Sendable () async throws -> User
    var logout: @Sendable () async throws -> Void
    var deleteAccount: @Sendable () async throws -> Void

}

extension AppleAuthClient: DependencyKey {
    static var liveValue: AppleAuthClient {
        .init(
            login: {
                    try await AuthService.loginWithApple()
            },
            logout: {
                
            },
            deleteAccount: {
                
            }
        )
    }

    static var testValue: AppleAuthClient {
        .init(
            login: {
                User(
                    id: "test-google-id",
                    name: "Test Google User",
                    email: "Test@google.com",
                    provider: .apple,
                    profileImageURL: nil,
                    localProfileImageData: nil
                )
            },
            logout: {},
            deleteAccount: {}
        )
    }
}

extension DependencyValues {
    var appleAuthClient: AppleAuthClient {
        get {
            self[AppleAuthClient.self]
        }
        set {
            self[AppleAuthClient.self] = newValue
        }
    }
}
