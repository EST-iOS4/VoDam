//
//  GoogleSignInClient.swift
//  Vodam
//
//  Created by 송영민 on 11/25/25.
//

import Dependencies
import GoogleSignIn

struct GoogleSignInClient {
    var signOut: @Sendable () -> Void
    var disconnect: @Sendable () async throws -> Void
    
}

extension GoogleSignInClient: DependencyKey {
    static var liveValue: GoogleSignInClient {
        .init (
            signOut: {
                GIDSignIn.sharedInstance.signOut()
            },
            disconnect: {
                try await GIDSignIn.sharedInstance.disconnect()
            }
        )
    }
    
    static var testValue: GoogleSignInClient {
        .init(signOut: {}, disconnect: {})
    }
    
    static var previewValue: GoogleSignInClient {
        .testValue
    }
    
}

extension DependencyValues {
    var googleSignInClient: GoogleSignInClient {
        get {
            self[GoogleSignInClient.self]
        } set {
            self[GoogleSignInClient.self] = newValue
        }
    }
}
