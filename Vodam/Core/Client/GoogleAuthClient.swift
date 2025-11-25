//
//  GoogleSignInClient.swift
//  Vodam
//
//  Created by 송영민 on 11/25/25.
//

import Dependencies
import GoogleSignIn

struct GoogleAuthClient {
    var login: @Sendable () async throws -> User
    var signOut: @Sendable () -> Void
    var disconnect: @Sendable () async throws -> Void

}

extension GoogleAuthClient: DependencyKey {
    static var liveValue: GoogleAuthClient {
        .init(
            login: {
                try await AuthService.loginWithGoogle()
            },
            signOut: {
                GIDSignIn.sharedInstance.signOut()
            },
            disconnect: {
                try await GIDSignIn.sharedInstance.disconnect()
            }
        )
    }

    static var testValue: GoogleAuthClient {
        .init(
            login: {
                User(
                    id: "test-google-id",
                    name: "Test Google User",
                    email: "Test@google.com",
                    provider: .google,
                    profileImageURL: nil,
                    localProfileImageData: nil
                )
            },
            signOut: {},
            disconnect: {}
        )
    }

//    static var previewValue: GoogleAuthClient {
//        .testValue
//    }

}

extension DependencyValues {
    var googleAuthClient: GoogleAuthClient {
        get {
            self[GoogleAuthClient.self]
        }
        set {
            self[GoogleAuthClient.self] = newValue
        }
    }
}
