//
//  GoogleSignInClient.swift
//  Vodam
//
//  Created by 송영민 on 11/25/25.
//

import Dependencies
import GoogleSignIn

struct GoogleAuthClient {
    var signOut: @Sendable () -> Void
    var disconnect: @Sendable () async throws -> Void

}

extension GoogleAuthClient: DependencyKey {
    static var liveValue: GoogleAuthClient {
        .init(
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
            signOut: {},
            disconnect: {}
        )
    }

    static var previewValue: GoogleAuthClient {
        .testValue
    }

}

extension DependencyValues {
    var googleSignInClient: GoogleAuthClient {
        get {
            self[GoogleAuthClient.self]
        }
        set {
            self[GoogleAuthClient.self] = newValue
        }
    }
}
