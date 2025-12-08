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
            disconnect: {
                do {
                    try await GIDSignIn.sharedInstance.disconnect()
                    print("Google disconnect 성공")
                } catch let error as NSError {
                    print("Google disconnect 실패")
                    print("Error Domain: \(error.domain)")
                    print("Error Code: \(error.code)")
                    print("Error Description: \(error.localizedDescription)")
                    print("User Info: \(error.userInfo)")
                    
                    // HTTP 응답 데이터가 있다면 출력
                    if let data = error.userInfo["data"] as? Data,
                       let jsonString = String(data: data, encoding: .utf8) {
                        print("  - Response Data: \(jsonString)")
                    }
                    
                    throw error
                }
            }
        )
    }
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
